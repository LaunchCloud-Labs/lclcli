# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LaunchCore::Auth::Authenticator do
  let(:valid_email)    { "user_#{SecureRandom.hex(4)}@example.com" }
  let(:valid_password) { 'Secure!Pass12' }

  # ── Signup ──────────────────────────────────────────────────
  describe '.signup' do
    context 'with valid attributes' do
      it 'creates a new user and returns ok status' do
        result = described_class.signup(
          email:      valid_email,
          password:   valid_password,
          first_name: 'Alice',
          last_name:  'Doe'
        )
        expect(result[:status]).to eq('ok')
        expect(result[:message]).to match(/Welcome/i)
      end

      it 'stores a bcrypt-hashed password (never plain-text)' do
        described_class.signup(email: valid_email, password: valid_password,
                               first_name: 'Alice', last_name: 'Doe')
        db   = LaunchCore::Database.connection
        user = db[:users].where(email: valid_email).first
        expect(user).not_to be_nil
        expect(user[:password_digest]).not_to eq(valid_password)
        expect(user[:password_digest]).to start_with('$2')
      end

      it 'sets auth_level to 1 for new users' do
        described_class.signup(email: valid_email, password: valid_password,
                               first_name: 'Alice', last_name: 'Doe')
        db   = LaunchCore::Database.connection
        user = db[:users].where(email: valid_email).first
        expect(user[:auth_level]).to eq(1)
      end

      it 'sets status to active' do
        described_class.signup(email: valid_email, password: valid_password,
                               first_name: 'Alice', last_name: 'Doe')
        db   = LaunchCore::Database.connection
        user = db[:users].where(email: valid_email).first
        expect(user[:status]).to eq('active')
      end
    end

    context 'with invalid attributes' do
      it 'rejects duplicate email' do
        described_class.signup(email: valid_email, password: valid_password,
                               first_name: 'A', last_name: 'B')
        result = described_class.signup(email: valid_email, password: valid_password,
                                        first_name: 'A', last_name: 'B')
        expect(result[:status]).to eq('error')
        expect(result[:message]).to match(/already registered|exists/i)
      end

      it 'rejects weak password (too short)' do
        result = described_class.signup(email: valid_email, password: 'short',
                                        first_name: 'A', last_name: 'B')
        expect(result[:status]).to eq('error')
        expect(result[:message]).to match(/password/i)
      end

      it 'rejects password without uppercase' do
        result = described_class.signup(email: valid_email, password: 'alllowercase12!',
                                        first_name: 'A', last_name: 'B')
        expect(result[:status]).to eq('error')
      end

      it 'rejects invalid email format' do
        result = described_class.signup(email: 'not-an-email', password: valid_password,
                                        first_name: 'A', last_name: 'B')
        expect(result[:status]).to eq('error')
        expect(result[:message]).to match(/email/i)
      end

      it 'rejects blank first name' do
        result = described_class.signup(email: valid_email, password: valid_password,
                                        first_name: '', last_name: 'B')
        expect(result[:status]).to eq('error')
      end
    end

    context 'with invite code' do
      it 'redeems a valid invite and links the inviting user' do
        # Create inviting user
        host  = create_test_user(
          email:    'host@example.com',
          password: 'HostPass1!ab'
        )
        db    = LaunchCore::Database.connection
        # Bump host to L2 so they can invite
        db[:users].where(id: host[:id]).update(auth_level: 2)

        host_result = login_user(email: 'host@example.com', password: 'HostPass1!ab')
        expect(host_result[:status]).to eq('ok')

        invite_result = described_class.generate_invite(
          user_id: host[:id],
          email:   valid_email
        )
        expect(invite_result[:status]).to eq('ok')
        code = invite_result[:invite_code]

        # Sign up with that code
        result = described_class.signup(
          email:       valid_email,
          password:    valid_password,
          first_name:  'Invited',
          last_name:   'Person',
          invite_code: code
        )
        expect(result[:status]).to eq('ok')

        invite = db[:invites].where(code: code).first
        expect(invite[:redeemed]).to eq(1).or eq(true)
      end

      it 'rejects an invalid invite code' do
        result = described_class.signup(
          email:       valid_email,
          password:    valid_password,
          first_name:  'A',
          last_name:   'B',
          invite_code: 'LCI-BOGUS'
        )
        expect(result[:status]).to eq('error')
        expect(result[:message]).to match(/invite/i)
      end
    end
  end

  # ── Login ────────────────────────────────────────────────────
  describe '.login' do
    before do
      described_class.signup(
        email:      valid_email,
        password:   valid_password,
        first_name: 'Bob',
        last_name:  'Smith'
      )
    end

    it 'returns ok with a JWT on valid credentials' do
      result = described_class.login(email: valid_email, password: valid_password)
      expect(result[:status]).to  eq('ok')
      expect(result[:token]).not_to be_nil
      expect(result[:token].split('.').length).to eq(3)
    end

    it 'returns error on wrong password' do
      result = described_class.login(email: valid_email, password: 'WrongPass1!')
      expect(result[:status]).to eq('error')
      expect(result[:token]).to  be_nil
    end

    it 'returns error for non-existent user' do
      result = described_class.login(email: 'nobody@example.com', password: valid_password)
      expect(result[:status]).to eq('error')
    end

    context 'account lockout after 5 failed attempts' do
      it 'locks the account and returns locked error' do
        5.times do
          described_class.login(email: valid_email, password: 'WrongPass1!x')
        end
        result = described_class.login(email: valid_email, password: valid_password)
        expect(result[:status]).to eq('error')
        expect(result[:message]).to match(/lock|too many/i)
      end

      it 'unlocks after the lockout period' do
        5.times { described_class.login(email: valid_email, password: 'WrongPass1!x') }
        Timecop.travel(Time.now + 16 * 60) do
          result = described_class.login(email: valid_email, password: valid_password)
          expect(result[:status]).to eq('ok')
        end
      end
    end
  end

  # ── TOTP ─────────────────────────────────────────────────────
  describe '.setup_totp / .verify_totp' do
    let!(:user) { create_test_user(email: valid_email, password: valid_password) }

    it 'generates a TOTP secret and provisioning URI' do
      result = described_class.setup_totp(user_id: user[:id])
      expect(result[:status]).to   eq('ok')
      expect(result[:secret]).not_to be_nil
      expect(result[:uri]).to include('otpauth://')
    end

    it 'verifies a valid TOTP code and upgrades auth_level to 2' do
      setup   = described_class.setup_totp(user_id: user[:id])
      totp    = ROTP::TOTP.new(setup[:secret])
      current = totp.now

      verify = described_class.verify_totp(user_id: user[:id], code: current)
      expect(verify[:status]).to eq('ok')

      db      = LaunchCore::Database.connection
      updated = db[:users].where(id: user[:id]).first
      expect(updated[:auth_level]).to be >= 2
    end

    it 'rejects an invalid TOTP code' do
      described_class.setup_totp(user_id: user[:id])
      result = described_class.verify_totp(user_id: user[:id], code: '000000')
      expect(result[:status]).to eq('error')
    end
  end

  # ── Invite generation ─────────────────────────────────────────
  describe '.generate_invite' do
    let!(:user) { create_test_user(email: valid_email, password: valid_password) }

    before do
      db = LaunchCore::Database.connection
      db[:users].where(id: user[:id]).update(auth_level: 2)
    end

    it 'creates an invite record and returns the code' do
      result = described_class.generate_invite(user_id: user[:id], email: 'friend@example.com')
      expect(result[:status]).to eq('ok')
      expect(result[:invite_code]).to match(/^LCI-/)

      db     = LaunchCore::Database.connection
      invite = db[:invites].where(code: result[:invite_code]).first
      expect(invite).not_to be_nil
      expect(invite[:invitee_email]).to eq('friend@example.com')
    end

    it 'denies invite generation below L2' do
      db = LaunchCore::Database.connection
      db[:users].where(id: user[:id]).update(auth_level: 1)
      result = described_class.generate_invite(user_id: user[:id], email: 'x@example.com')
      expect(result[:status]).to eq('error')
    end
  end

  # ── Auth level evaluation ─────────────────────────────────────
  describe '.evaluate_auth_level' do
    let!(:user) { create_test_user(email: valid_email, password: valid_password) }

    it 'returns L1 for a fresh user' do
      level = described_class.evaluate_auth_level(user_id: user[:id])
      expect(level).to eq(1)
    end

    it 'returns L2 when totp_enabled is true' do
      db = LaunchCore::Database.connection
      db[:users].where(id: user[:id]).update(totp_enabled: 1, totp_secret: 'AABB')
      level = described_class.evaluate_auth_level(user_id: user[:id])
      expect(level).to be >= 2
    end

    it 'returns L4 when L1-L3 are met and account is 30+ days old' do
      db = LaunchCore::Database.connection
      db[:users].where(id: user[:id]).update(
        totp_enabled: 1,
        totp_secret:  'AABB',
        kyc_verified: 1,
        created_at:   (Time.now - 31 * 24 * 3600).iso8601
      )
      level = described_class.evaluate_auth_level(user_id: user[:id])
      expect(level).to eq(4)
    end
  end

  # ── generate_slug ─────────────────────────────────────────────────────
  describe '.generate_slug' do
    it 'produces a lowercase hyphenated slug from the email local part' do
      slug = described_class.generate_slug('John.Doe@example.com')
      expect(slug).to match(/\Ajohn-doe-[a-f0-9]{8}\z/)
    end
  end
end
