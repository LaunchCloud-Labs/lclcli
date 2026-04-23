# frozen_string_literal: true

module LaunchCore
  module CLI
    # Routes slash commands to the correct handler
    # rubocop:disable Metrics/ClassLength
    class Dispatcher
      T = Config::THEME

      def initialize(session)
        @session = session
      end

      # rubocop:disable Metrics/CyclomaticComplexity, Metrics/AbcSize
      def dispatch(input, extra_args = [])
        parts   = input.strip.split + extra_args.reject { |a| a == '--json' }
        command = parts.shift.downcase
        args    = parse_args(parts)

        case command
        when '/help'           then cmd_help(args)
        when '/status'         then cmd_status(args)
        when '/auth/login'     then cmd_login(args)
        when '/auth/signup'    then cmd_signup(args)
        when '/auth/logout'    then cmd_logout
        when '/auth/invite'    then cmd_invite(args)
        when '/settings'       then cmd_settings(args)
        when '/settings/2fa'   then cmd_2fa(args)
        when '/settings/kyc'   then cmd_kyc(args)
        when '/settings/password' then cmd_change_password(args)
        when '/settings/profile'  then cmd_profile(args)
        when '/voice'          then dispatch_product(:voice, args)
        when '/tunnel'         then dispatch_product(:tunnel, args)
        when '/portal'         then dispatch_product(:portal, args)
        when '/meetings'       then dispatch_product(:meetings, args)
        when '/workforce'      then dispatch_product(:workforce, args)
        when '/scheduler'      then dispatch_product(:scheduler, args)
        when '/neobank'        then dispatch_product(:neobank, args)
        when '/brinkspay'      then dispatch_product(:brinkspay, args)
        when '/tradeshield'    then dispatch_product(:tradeshield, args)
        when '/stophold'       then dispatch_product(:stophold, args)
        when '/arbiter'        then dispatch_product(:arbiter, args)
        when '/admin'          then cmd_admin(args)
        when '/robot'          then cmd_robot(args)
        when '/update'         then cmd_update(args)
        else
          result = { status: 'error', message: "Unknown command: #{command}. Try /help" }
          return Output.json_response(**result) if Output.json_mode

          Output.warning(result[:message])
          result

        end
      end
      # rubocop:enable Metrics/CyclomaticComplexity, Metrics/AbcSize

      private

      # --------- Core Commands ---------

      def cmd_help(_args)
        if Output.json_mode
          return Output.json_response(
            status: 'ok',
            message: 'Available commands',
            command: '/help',
            commands: help_data
          )
        end

        Output.blank
        Output.header('LaunchCore Command — Available Commands')
        Output.blank

        sections = help_data
        sections.each do |section|
          Output.primary("  #{section[:section]}")
          Output.divider('─', :muted)
          section[:commands].each do |cmd|
            name_col = "#{T[:accent][:ansi]}#{cmd[:cmd].ljust(30)}#{T[:reset]}"
            $stdout.puts "  #{name_col} #{T[:muted][:ansi]}#{cmd[:desc]}#{T[:reset]}"
          end
          Output.blank
        end

        Output.muted('  Auth Level required shown as [L1-L4]. Use /settings to upgrade.')
        Output.blank
      end

      # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity
      def cmd_status(_args)
        if @session.logged_in?
          claims = @session.current_user
          # Support both JWT claims (string keys) and DB/test hashes (symbol keys)
          uid    = (claims&.dig('sub') || claims&.dig(:id))&.to_i
          em     = claims&.dig('email') || claims&.dig(:email)
          uc     = claims&.dig('user_class') || claims&.dig(:user_class)
          al     = (claims&.dig('auth_level') || claims&.dig(:auth_level) || 1).to_i

          db_user = uid ? Database::Models.users.where(id: uid).first : nil

          data = {
            authenticated: true,
            email: em,
            user_class: Config::USER_CLASSES[uc] || uc,
            auth_level: al,
            auth_label: Config::AUTH_LEVELS[al],
            status: db_user&.dig(:status),
            account_days: db_user&.dig(:account_active_days) || 0,
            kyc_verified: db_user&.dig(:kyc_verified) == 1
          }
          if Output.json_mode
            Output.json_response(status: 'ok', message: 'Session active', command: '/status',
                                 version: LaunchCore::VERSION, data: data)
          else
            Output.blank
            Output.header('Session Status')
            Output.blank
            Output.success("Authenticated as #{data[:email]}")
            Output.info("Class:      #{data[:user_class]}")
            Output.info("Auth Level: L#{data[:auth_level]} — #{data[:auth_label]}")
            Output.info("KYC:        #{data[:kyc_verified] ? 'Verified' : 'Pending'}")
            Output.info("Days Active: #{data[:account_days]}")
            Output.blank
          end
        else
          msg = 'Not authenticated. Use /auth/login'
          if Output.json_mode
            Output.json_response(status: 'unauthenticated', message: msg, command: '/status',
                                 version: LaunchCore::VERSION)
          else
            Output.warning(msg)
          end
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/PerceivedComplexity

      def cmd_login(args)
        if @session.logged_in?
          msg = 'Already authenticated.'
          return Output.json_mode ? Output.json_response(status: 'already_logged_in', message: msg,
                                                         command: '/auth/login') : Output.info(msg)
        end

        if Output.json_mode && args[:email] && args[:password]
          # Non-interactive JSON login (used by Sinatra bridge)
          return perform_login(email: args[:email], password: args[:password])
        end

        Output.blank
        Output.header('LaunchCore — Login')
        Output.blank

        email    = args[:email]    || Output.prompt_field('Email')
        password = args[:password] || Output.prompt_field('Password', secret: true)

        perform_login(email: email, password: password)
      end

      def perform_login(email:, password:)
        user  = Auth::Authenticator.login!(email: email, password: password)
        ents  = begin
          JSON.parse(user[:entitlements] || '{}')
        rescue StandardError
          {}
        end

        token, = Auth::JWTManager.encode(
          user_id: user[:id],
          email: user[:email],
          user_class: user[:user_class],
          auth_level: user[:auth_level],
          entitlements: ents
        )
        @session.store!(token)

        if Output.json_mode
          Output.json_response(
            status: 'ok',
            message: 'Login successful',
            command: '/auth/login',
            data: { email: user[:email], auth_level: user[:auth_level], user_class: user[:user_class] }
          )
        else
          Output.blank
          Output.success("Welcome back, #{user[:first_name]}!")
          Output.info("Auth Level: L#{user[:auth_level]} — #{Config::AUTH_LEVELS[user[:auth_level]]}")
          Output.muted("Session saved to #{Config::SESSION_FILE}")
          Output.blank
        end
      rescue Auth::AuthError => e
        if Output.json_mode
          Output.json_response(status: 'error', message: e.message, command: '/auth/login')
        else
          Output.critical(e.message)
        end
      end

      # rubocop:disable Metrics/PerceivedComplexity
      def cmd_signup(args)
        Output.blank
        Output.header('LaunchCore — Create Account')
        Output.blank

        if Output.json_mode && args[:email] && args[:password]
          return perform_signup(
            email: args[:email],
            password: args[:password],
            first_name: args[:first_name] || 'User',
            last_name: args[:last_name] || 'Account',
            phone: args[:phone],
            invite_code: args[:invite_code]
          )
        end

        Output.info('Placeholder Payment — Your card will NOT be charged during beta.')
        Output.blank

        email       = Output.prompt_field('Email')
        first_name  = Output.prompt_field('First Name')
        last_name   = Output.prompt_field('Last Name')
        phone       = Output.prompt_field('Phone (optional, press Enter to skip)')
        invite_code = Output.prompt_field('Invite Code (optional, press Enter to skip)')

        Output.blank
        Output.primary('Credit Card (Placeholder — Stored NOWHERE, Beta Only)')
        Output.prompt_field('Card Number')        # deliberately not stored
        Output.prompt_field('Expiry (MM/YY)')     # deliberately not stored
        Output.prompt_field('CVV', secret: true)  # deliberately not stored
        Output.blank

        password  = Output.prompt_field('Create Password', secret: true)
        password2 = Output.prompt_field('Confirm Password', secret: true)

        unless password == password2
          Output.critical('Passwords do not match.')
          return
        end

        perform_signup(
          email: email,
          password: password,
          first_name: first_name,
          last_name: last_name,
          phone: phone.empty? ? nil : phone,
          invite_code: invite_code.empty? ? nil : invite_code
        )
      end

      # rubocop:disable Metrics/ParameterLists
      def perform_signup(email:, password:, first_name:, last_name:, phone: nil, invite_code: nil)
        user = Auth::Authenticator.signup!(
          email: email,
          password: password,
          first_name: first_name,
          last_name: last_name,
          phone: phone,
          invite_code: invite_code
        )

        if Output.json_mode
          Output.json_response(
            status: 'ok',
            message: 'Account created successfully',
            command: '/auth/signup',
            data: { email: user[:email], user_class: user[:user_class], auth_level: user[:auth_level] }
          )
        else
          Output.blank
          Output.success("Account created! Welcome, #{user[:first_name]}.")
          Output.info("Auth Level: L1 — #{Config::AUTH_LEVELS[1]}")
          Output.info('Next step: Enable 2FA with /settings/2fa')
          Output.muted("A welcome email has been sent to #{user[:email]}")
          Output.blank
        end
      rescue Auth::AuthError => e
        if Output.json_mode
          Output.json_response(status: 'error', message: e.message, command: '/auth/signup')
        else
          Output.critical(e.message)
        end
      end
      # rubocop:enable Metrics/ParameterLists

      def cmd_logout
        if @session.logged_in?
          claims = @session.current_user
          em     = claims&.dig('email') || claims&.dig(:email) || 'user'
          @session.logout!
          if Output.json_mode
            return Output.json_response(status: 'ok', message: 'Logged out successfully', command: '/auth/logout')
          end

          Output.success("Logged out. Goodbye, #{em}.")

        else
          msg = 'No active session.'
          return Output.json_response(status: 'ok', message: msg, command: '/auth/logout') if Output.json_mode

          Output.muted(msg)

        end
      end

      def cmd_invite(args)
        @session.require_auth!(min_level: 2)
        role  = args[:role] || 'company_agent'
        email = args[:email]
        code  = Auth::Authenticator.generate_invite!(
          created_by_id: @session.user_id,
          email: email,
          role: role
        )

        if Output.json_mode
          Output.json_response(status: 'ok', message: 'Invite generated', command: '/auth/invite',
                               data: { code: code, role: role, email: email })
        else
          Output.blank
          Output.success("Invite code generated: #{code}")
          Output.info("Role: #{Config::USER_CLASSES[role] || role}")
          Output.info("Email: #{email || 'Not restricted'}") if email
          Output.muted('Code expires in 7 days. Share via email or direct message.')
          Output.blank
        end
      rescue Auth::AuthError => e
        if Output.json_mode
          Output.json_response(status: 'error', message: e.message, command: '/auth/invite')
        else
          Output.critical(e.message)
        end
      end
      # rubocop:enable Metrics/PerceivedComplexity

      def cmd_settings(_args)
        @session.require_auth!
        if Output.json_mode
          Output.json_response(
            status: 'ok',
            message: 'Settings overview',
            command: '/settings',
            data: {
              commands: ['/settings/2fa', '/settings/kyc', '/settings/password', '/settings/profile']
            }
          )
        else
          Output.blank
          Output.header('Account Settings')
          Output.blank
          Output.info('/settings/2fa      — Configure TOTP two-factor authentication (→ L2)')
          Output.info('/settings/kyc      — Submit KYC / identity verification (→ L3)')
          Output.info('/settings/password — Change your password')
          Output.info('/settings/profile  — View / update profile info')
          Output.blank
        end
      rescue Auth::AuthError => e
        Output.critical(e.message)
      end

      # rubocop:disable Metrics/PerceivedComplexity
      def cmd_2fa(args)
        @session.require_auth!

        if args[:code]
          Auth::Authenticator.verify_totp!(@session.user_id, args[:code])
          new_level = Auth::Authenticator.evaluate_auth_level!(@session.user_id)
          if Output.json_mode
            Output.json_response(status: 'ok', message: '2FA verified. Auth level updated.',
                                 command: '/settings/2fa', data: { auth_level: new_level })
          else
            Output.success("2FA verified! Auth Level upgraded to L#{new_level}.")
          end
        else
          secret, uri = Auth::Authenticator.setup_totp!(@session.user_id)
          if Output.json_mode
            Output.json_response(status: 'ok', message: 'TOTP secret generated',
                                 command: '/settings/2fa', data: { secret: secret, otpauth_uri: uri })
          else
            Output.blank
            Output.header('Two-Factor Authentication Setup')
            Output.blank
            Output.info("Secret: #{secret}")
            Output.info('OTPAuth URI (scan with authenticator app):')
            Output.muted("  #{uri}")
            Output.blank
            Output.muted('Then run: /settings/2fa --code=YOUR_CODE to verify and activate L2.')
            Output.blank
          end
        end
      rescue Auth::AuthError => e
        if Output.json_mode
          Output.json_response(status: 'error', message: e.message, command: '/settings/2fa')
        else
          Output.critical(e.message)
        end
      end
      # rubocop:enable Metrics/PerceivedComplexity

      def cmd_kyc(_args)
        @session.require_auth!(min_level: 2)

        if Output.json_mode
          Output.json_response(
            status: 'ok',
            message: 'KYC portal',
            command: '/settings/kyc',
            data: {
              instructions: 'Upload government-issued ID via the web portal at ' \
                            "https://#{Config::DOMAIN}/kyc"
            }
          )
        else
          Output.blank
          Output.header('KYC / Identity Verification')
          Output.blank
          Output.info('Required for Auth Level 3 (NeoBank Ready)')
          Output.muted("Submit your government-issued ID at https://#{Config::DOMAIN}/kyc")
          Output.muted('Review typically takes 1–2 business days.')
          Output.blank
        end
      rescue Auth::AuthError => e
        Output.critical(e.message)
      end

      def cmd_change_password(_args)
        @session.require_auth!
        Output.blank
        Output.header('Change Password')
        current = Output.prompt_field('Current Password', secret: true)
        Auth::Authenticator.login!(email: @session.email, password: current)
        new_pass = Output.prompt_field('New Password', secret: true)
        confirm  = Output.prompt_field('Confirm New Password', secret: true)

        unless new_pass == confirm
          Output.critical('Passwords do not match.')
          return
        end

        Auth::Authenticator.send(:validate_password_strength!, new_pass)
        digest = BCrypt::Password.create(new_pass, cost: 12)
        Database::Models.users.where(id: @session.user_id).update(
          password_digest: digest,
          updated_at: Time.now.utc.iso8601
        )
        Database::Models.log(user_id: @session.user_id, action: 'password_changed', resource: 'user')
        Output.success('Password changed successfully.')
      rescue Auth::AuthError => e
        Output.critical(e.message)
      end

      def cmd_profile(_args)
        @session.require_auth!
        user = Database::Models.users.where(id: @session.user_id).first
        data = {
          id: user[:id],
          email: user[:email],
          first_name: user[:first_name],
          last_name: user[:last_name],
          phone: user[:phone],
          user_class: Config::USER_CLASSES[user[:user_class]] || user[:user_class],
          auth_level: user[:auth_level],
          kyc: user[:kyc_verified] == 1,
          created_at: user[:created_at]
        }

        if Output.json_mode
          Output.json_response(status: 'ok', message: 'Profile', command: '/settings/profile', data: data)
        else
          Output.blank
          Output.header('Your Profile')
          Output.blank
          data.each { |k, v| Output.info("#{k.to_s.ljust(15)}: #{v}") }
          Output.blank
        end
      rescue Auth::AuthError => e
        Output.critical(e.message)
      end

      # --------- Admin / Robot Modules ---------

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
      def cmd_admin(args)
        @session.require_auth!
        claims = @session.current_user
        email  = (claims&.dig('email') || claims&.dig(:email)).to_s
        uclass = claims&.dig('user_class') || claims&.dig(:user_class)

        # Restricted to LCL super-users
        is_lcl_admin = email.end_with?('@launchcloudlabs.com') || uclass == 'administrator'
        unless is_lcl_admin
          raise Auth::AuthError, "Forbidden: /admin requires LCL Administrator status. Current: #{email}"
        end

        if args[:companies]
          companies = Database::Models.companies.all
          return Output.json_response(status: 'ok', data: companies) if Output.json_mode

          Output.header('LCL Global Company Registry')
          companies.each do |c|
            $stdout.puts "  #{c[:slug].ljust(15)} | #{c[:name].ljust(25)} | [#{c[:status]}]"
          end
        elsif args[:provision]
          slug = args[:company] || args[:provision]
          name = args[:name] || slug.upcase
          owner_email = args[:owner]

          raise 'Missing --company or --owner' unless slug && owner_email

          # Create company
          id = Database::Models.companies.insert(
            name: name,
            slug: slug.upcase,
            status: 'active',
            entitlements: JSON.generate({}),
            created_at: Time.now.utc.iso8601,
            updated_at: Time.now.utc.iso8601
          )

          # Assign owner if user exists
          owner = Database::Models.users.where(email: owner_email.downcase).first
          Database::Models.companies.where(id: id).update(owner_id: owner[:id]) if owner

          result = { status: 'ok', message: "Company #{slug} provisioned successfully.", id: id }
          return Output.json_response(**result) if Output.json_mode

          Output.success(result[:message])
        elsif args[:grant] || args[:revoke]
          slug = args[:company]
          mod  = args[:module]
          raise 'Missing --company or --module' unless slug && mod

          company = Database::Models.companies.where(slug: slug.upcase).first
          raise "Company not found: #{slug}" unless company

          ents = JSON.parse(company[:entitlements] || '{}')
          ents[mod] = args[:grant] ? true : false
          Database::Models.companies.where(id: company[:id]).update(
            entitlements: JSON.generate(ents),
            updated_at: Time.now.utc.iso8601
          )
          result = { status: 'ok', message: "#{args[:grant] ? 'Granted' : 'Revoked'} #{mod} to #{slug}" }
          return Output.json_response(**result) if Output.json_mode

          Output.success(result[:message])
        else
          Output.info('Usage: /admin --companies')
          Output.info('Usage: /admin --provision=SLUG --name="Name" --owner=EMAIL')
          Output.info('Usage: /admin --company=SLUG --module=MOD --grant|--revoke')
        end
      rescue StandardError => e
        Output.json_mode ? Output.json_response(status: 'error', message: e.message) : Output.critical(e.message)
      end

      def cmd_robot(args)
        # Autonomous Data Bridge
        if args[:sync]
          slug = args[:company] || args[:sync]
          company = Database::Models.companies.where(slug: slug.upcase).first
          unless company
            msg = "Company not found: #{slug}"
            return Output.json_mode ? Output.json_response(status: 'error', message: msg) : Output.error(msg)
          end

          users = Database::Models.users.where(company_id: company[:id]).all
          # Transform for Spoke consumption
          payload = users.map do |u|
            {
              email: u[:email],
              fullname: "#{u[:first_name]} #{u[:last_name]}".strip,
              role: u[:user_class] == 'power_user' ? 'ADMIN' : 'EMPLOYEE'
            }
          end

          return Output.json_response(status: 'ok', message: "Data exported for #{slug}", company: slug, data: payload) if Output.json_mode

          Output.header("Robot Sync Payload: #{slug}")
          puts JSON.pretty_generate(payload)
        else
          Output.info('Usage: /robot --sync=SLUG [--json]')
        end
      end

      def cmd_update(_args)
        Output.header('Over-The-Air Update (OTA)')
        Output.info('Checking for Hub and Spoke updates from GitHub...')
        
        # Perform git pull on Hub and Spokes if they exist
        ['lclcli', 'lcl-payroll', 'LCL-TimeClock'].each do |repo|
          path = File.expand_path("~/projects/#{repo}")
          if File.directory?(path)
            Output.info("Updating #{repo}...")
            res = `cd #{path} && git pull origin master 2>&1 || git pull origin main 2>&1`
            if $?.success?
              Output.success("#{repo} updated: #{res.strip.lines.last.strip}")
            else
              Output.warning("#{repo} update failed: #{res.strip}")
            end
          end
        end
        Output.success("OTA Update Complete. Please restart the CLI.")
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity

      # --------- Product dispatch ---------

      def dispatch_product(key, args)
        config = Config::PRODUCTS[key]
        raise ArgumentError, "Unknown product: #{key}" unless config

        begin
          @session.require_auth!(min_level: config[:min_level], min_class: config[:min_class])
        rescue Auth::AuthError => e
          return Output.json_response(status: 'error', message: e.message, command: "/#{key}") if Output.json_mode

          Output.critical(e.message)
          print_level_upgrade_hint(config[:min_level])
          return { status: 'error', message: e.message }
        end

        # --- AUTO-DOWNLOAD / EXECUTION LOGIC ---
        binary_name = "lcl-#{key}"
        unless system("command -v #{binary_name} > /dev/null 2>&1")
          Output.info("Module #{binary_name} not found. Checking entitlements...")
          # Verify entitlement in JWT or DB
          if @session.entitlements[key.to_s] || @session.entitlements[key.to_sym]
            Output.info("Entitlement verified. Triggering auto-installation of #{binary_name}...")
            # Simulated Installer Call (In production, this points to your GitHub raw installer)
            installer_url = "https://raw.githubusercontent.com/LaunchCloud-Labs/LaunchCore-Command-#{key.capitalize}/master/install.sh"
            system("curl -sSL #{installer_url} | bash")
          else
            msg = "Module not installed and no entitlement found for #{key}. Please subscribe to unlock."
            return Output.json_response(status: 'error', message: msg) if Output.json_mode
            Output.warning(msg)
            return
          end
        end

        # Execute the Spoke with the Hub's Auth Token
        system("#{binary_name} /#{args.join(' ')} --auth-token=#{@session.token}")
      end

      def print_level_upgrade_hint(required_level)
        Output.blank
        case required_level
        when 2 then Output.muted('→ Enable 2FA with /settings/2fa to reach L2')
        when 3 then Output.muted('→ Complete KYC at /settings/kyc to reach L3')
        when 4 then Output.muted('→ Maintain 30-day active account + L1-L3 to reach L4')
        end
      end

      # --------- Help data ---------

      def help_data
        [
          {
            section: 'Authentication',
            commands: [
              { cmd: '/auth/login',   desc: 'Authenticate with email + password' },
              { cmd: '/auth/signup',  desc: 'Create a new account (placeholder payment)' },
              { cmd: '/auth/logout',  desc: 'End session and revoke token' },
              { cmd: '/auth/invite',  desc: 'Generate an invite code [L2+]' }
            ]
          },
          {
            section: 'Account Settings',
            commands: [
              { cmd: '/settings',           desc: 'Settings overview' },
              { cmd: '/settings/2fa',       desc: 'Configure TOTP 2FA → Auth Level 2' },
              { cmd: '/settings/kyc',       desc: 'Submit KYC verification → Auth Level 3' },
              { cmd: '/settings/password',  desc: 'Change password' },
              { cmd: '/settings/profile',   desc: 'View profile information' }
            ]
          },
          {
            section: 'System',
            commands: [
              { cmd: '/status',  desc: 'Show current session + auth level' },
              { cmd: '/help',    desc: 'Show this help menu' }
            ]
          },
          {
            section: 'Products (11-Stack)',
            commands: Config::PRODUCTS.map do |key, p|
              { cmd: "/#{key}", desc: "#{p[:name]}  [L#{p[:min_level]}]  — #{p[:tech]}" }
            end
          }
        ]
      end

      # --------- Arg parser ---------

      # Parses "--key=value" and "--flag" into a symbol-keyed hash
      def parse_args(parts)
        result = {}
        parts.each do |part|
          next unless part =~ /\A--([a-z_]+)(?:=(.+))?\z/

          key = Regexp.last_match(1).to_sym
          val = Regexp.last_match(2).nil? || Regexp.last_match(2)
          result[key] = val
        end
        result
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
