# frozen_string_literal: true

require 'bcrypt'
require 'rotp'
require 'securerandom'

module LaunchCore
  module Auth
    # Handles all user authentication operations:
    # signup, login, 2FA, invite validation, auth level promotion
    class Authenticator
      MAX_ATTEMPTS = Config::MAX_LOGIN_ATTEMPTS
      LOCKOUT_SEC  = Config::LOCKOUT_DURATION

      # --------- Signup ---------

      # rubocop:disable Metrics/AbcSize, Metrics/ParameterLists
      def self.signup!(email:, password:, first_name:, last_name:, phone: nil,
                       invite_code: nil, user_class: 'power_user')
        validate_email!(email)
        validate_password_strength!(password)
        raise AuthError, 'First name cannot be blank.'  if first_name.to_s.strip.empty?
        raise AuthError, 'Last name cannot be blank.'   if last_name.to_s.strip.empty?

        if Database::Models.users.where(Sequel.function(:lower, :email) => email.downcase).any?
          raise AuthError, "An account with #{email} already exists."
        end

        company_id = nil
        if invite_code
          invite = redeem_invite!(invite_code, email)
          user_class = invite[:role]
          company_id = invite[:company_id]
        end

        digest = BCrypt::Password.create(password, cost: 12)
        generate_slug(email)

        user_id = Database::Models.users.insert(
          email: email.downcase.strip,
          password_digest: digest,
          first_name: first_name.strip,
          last_name: last_name.strip,
          phone: phone&.strip,
          user_class: user_class,
          auth_level: 1,
          status: 'active',
          entitlements: JSON.generate(default_entitlements),
          invite_code: invite_code,
          company_id: company_id,
          created_at: Time.now.utc.iso8601,
          updated_at: Time.now.utc.iso8601
        )

        if invite_code
          Database::Models.invites
                          .where(code: invite_code)
                          .update(used_by: user_id, redeemed: 1, used_at: Time.now.utc.iso8601)
        end

        Database::Models.log(
          user_id: user_id,
          action: 'signup',
          resource: 'user',
          metadata: { email: email, class: user_class }
        )

        Mailer.welcome(email: email, first_name: first_name)

        Database::Models.users.where(id: user_id).first
      end
      # rubocop:enable Metrics/AbcSize, Metrics/ParameterLists

      # --------- Login ---------

      def self.login!(email:, password:)
        user = Database::Models.users
                               .where(Sequel.function(:lower, :email) => email.downcase.strip)
                               .first
        raise AuthError, 'Invalid email or password.' unless user
        raise AuthError, 'Account suspended. Contact support.' if user[:status] == 'suspended'

        check_lockout!(user)

        unless BCrypt::Password.new(user[:password_digest]) == password
          increment_failures!(user[:id])
          remaining = MAX_ATTEMPTS - (user[:failed_logins] + 1)
          raise AuthError, "Invalid email or password. #{remaining} attempts remaining."
        end

        reset_failures!(user[:id])
        update_last_login!(user[:id])

        Database::Models.log(
          user_id: user[:id],
          action: 'login',
          resource: 'session',
          status: 'success'
        )

        user
      end

      # --------- TOTP Setup ---------

      def self.setup_totp!(user_id)
        secret = ROTP::Base32.random
        totp   = ROTP::TOTP.new(secret, issuer: Config::COMPANY_NAME)
        Database::Models.users.where(id: user_id).update(totp_secret: secret)
        uri = totp.provisioning_uri(Database::Models.users.where(id: user_id).first[:email])
        [secret, uri]
      end

      # rubocop:disable Naming/PredicateMethod
      def self.verify_totp!(user_id, code)
        user = Database::Models.users.where(id: user_id).first
        raise AuthError, 'TOTP not configured.' unless user[:totp_secret]

        totp   = ROTP::TOTP.new(user[:totp_secret], issuer: Config::COMPANY_NAME)
        result = totp.verify(code, drift_behind: 30, drift_ahead: 30)
        raise AuthError, 'Invalid or expired TOTP code.' unless result

        unless user[:totp_enabled] == 1
          Database::Models.users.where(id: user_id).update(
            totp_enabled: 1,
            auth_level: [user[:auth_level], 2].max,
            updated_at: Time.now.utc.iso8601
          )
          Database::Models.log(user_id: user_id, action: '2fa_enabled', resource: 'user')
        end

        true
      end
      # rubocop:enable Naming/PredicateMethod

      def self.generate_invite!(created_by_id:, email: nil, role: 'company_agent', company_id: nil)
        user = Database::Models.users.where(id: created_by_id).first
        raise AuthError, 'Invite requires Auth Level 2+' unless user[:auth_level] >= 2

        code = "LCI-#{SecureRandom.hex(8).upcase}"
        Database::Models.invites.insert(
          code: code,
          inviter_id: created_by_id,
          invitee_email: email,
          role: role,
          company_id: company_id,
          expires_at: (Time.now + (7 * 24 * 3600)).utc.iso8601,
          created_at: Time.now.utc.iso8601
        )

        Mailer.invite(to: email, code: code, role: role) if email
        code
      end

      # --------- Auth Level Evaluation ---------

      def self.evaluate_auth_level!(user_id)
        user  = Database::Models.users.where(id: user_id).first
        level = 1
        level = [level, 2].max if user[:totp_enabled] == 1
        level = [level, 3].max if user[:kyc_verified] == 1
        created = begin
          Time.parse(user[:created_at].to_s)
        rescue StandardError
          Time.now
        end
        days_active = [(Time.now - created) / 86_400, 0].max.to_i
        level = 4 if level >= 3 && days_active >= 30
        if level != user[:auth_level]
          Database::Models.users.where(id: user_id).update(auth_level: level, updated_at: Time.now.utc.iso8601)
          Database::Models.log(user_id: user_id, action: 'auth_level_updated', metadata: { new_level: level })
        end
        level
      end

      def self.validate_email!(email)
        raise AuthError, 'Invalid email format.' unless email.match?(/\A[^@\s]+@[^@\s]+\.[^@\s]+\z/)
      end

      def self.validate_password_strength!(password)
        raise AuthError, 'Password must be at least 12 characters.' if password.length < 12
        raise AuthError, 'Password must contain uppercase, lowercase, digit, and symbol.' unless
          password.match?(/[A-Z]/) && password.match?(/[a-z]/) && password.match?(/\d/) && password.match?(/\W/)
      end

      def self.check_lockout!(user)
        return unless user[:locked_until]

        locked_until = Time.parse(user[:locked_until].to_s)
        return if Time.now > locked_until

        mins = ((locked_until - Time.now) / 60).ceil
        raise AuthError, "Account locked. Try again in #{mins} minute(s)."
      end

      def self.increment_failures!(user_id)
        user     = Database::Models.users.where(id: user_id).first
        attempts = (user[:failed_logins] || 0) + 1
        updates  = { failed_logins: attempts, updated_at: Time.now.utc.iso8601 }
        updates[:locked_until] = (Time.now + LOCKOUT_SEC).utc.iso8601 if attempts >= MAX_ATTEMPTS
        Database::Models.users.where(id: user_id).update(updates)
      end

      def self.reset_failures!(user_id)
        Database::Models.users.where(id: user_id).update(
          failed_logins: 0,
          locked_until: nil,
          updated_at: Time.now.utc.iso8601
        )
      end

      def self.update_last_login!(user_id)
        user = Database::Models.users.where(id: user_id).first
        user[:account_active_days] || 0
        created = begin
          Time.parse(user[:created_at].to_s)
        rescue StandardError
          Time.now
        end
        days_active = [(Time.now - created) / 86_400, 0].max.to_i
        Database::Models.users.where(id: user_id).update(
          last_login_at: Time.now.utc.iso8601,
          account_active_days: days_active,
          updated_at: Time.now.utc.iso8601
        )
      end

      # rubocop:disable Metrics/PerceivedComplexity
      def self.redeem_invite!(code, email)
        invite = Database::Models.invites.where(code: code, revoked: 0).first
        raise AuthError, 'Invalid or expired invite code.' unless invite
        raise AuthError, 'Invite code already used.' if invite[:used_by]

        if invite[:expires_at]
          expires = begin
            Time.parse(invite[:expires_at].to_s)
          rescue StandardError
            nil
          end
          raise AuthError, 'Invite code has expired.' if expires && Time.now > expires
        end
        if invite[:invitee_email] && invite[:invitee_email].downcase != email.downcase
          raise AuthError, 'This invite is restricted to a specific email address.'
        end

        invite
      end
      # rubocop:enable Metrics/PerceivedComplexity

      def self.generate_slug(email)
        email.split('@').first.downcase.gsub(/[^a-z0-9]/, '-') + "-#{SecureRandom.hex(4)}"
      end

      def self.default_entitlements
        {
          voice: false, tunnel: false, portal: false, meetings: false,
          workforce: false, scheduler: false, neobank: false,
          brinkspay: false, tradeshield: false, stophold: false, arbiter: false
        }
      end

      # ── Non-bang public wrappers (return structured hashes, rescue AuthError) ──

      def self.signup(email:, password:, first_name:, last_name:, **)
        user = signup!(email: email, password: password,
                       first_name: first_name, last_name: last_name)
        { status: 'ok', message: "Welcome, #{user[:first_name]}! Your account is active." }
      rescue AuthError => e
        { status: 'error', message: e.message }
      end

      def self.login(email:, password:)
        user          = login!(email: email, password: password)
        token, _jti   = Auth::JWTManager.encode(
          user_id: user[:id],
          email: user[:email],
          user_class: user[:user_class],
          auth_level: user[:auth_level],
          entitlements: JSON.parse(user[:entitlements] || '{}')
        )
        { status: 'ok', token: token }
      rescue AuthError => e
        { status: 'error', message: e.message, token: nil }
      end

      def self.setup_totp(user_id:)
        secret, uri = setup_totp!(user_id)
        { status: 'ok', secret: secret, uri: uri }
      rescue AuthError => e
        { status: 'error', message: e.message }
      end

      def self.verify_totp(user_id:, code:)
        verify_totp!(user_id, code)
        { status: 'ok', message: '2FA verified successfully.' }
      rescue AuthError => e
        { status: 'error', message: e.message }
      end

      def self.generate_invite(user_id:, email: nil, role: 'company_agent', company_id: nil)
        code = generate_invite!(created_by_id: user_id, email: email, role: role, company_id: company_id)
        { status: 'ok', invite_code: code }
      rescue AuthError => e
        { status: 'error', message: e.message }
      end

      def self.evaluate_auth_level(user_id:)
        evaluate_auth_level!(user_id)
      rescue AuthError
        nil
      end
    end
  end
end
