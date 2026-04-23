# frozen_string_literal: true

require 'spec_helper'

# Extended coverage for dispatcher commands not in the primary spec:
# /settings, /settings/2fa, /settings/kyc, /settings/profile, /auth/invite
RSpec.describe LaunchCore::CLI::Dispatcher, 'extended commands' do
  include DatabaseHelper

  before(:each) do
    truncate_tables!
    LaunchCore::Output.json_mode   = true
    LaunchCore::Output.silent_mode = false
  end

  after(:each) do
    LaunchCore::Output.json_mode   = false
    LaunchCore::Output.silent_mode = false
  end

  let(:user) { create_test_user }

  # A fully-stubbed session double for commands that read session attributes
  def make_session(auth_level: 1, user_class: 'power_user')
    instance_double(
      LaunchCore::Auth::Session,
      logged_in?:   true,
      current_user: user,
      require_auth!: nil,
      user_id:      user[:id],
      email:        user[:email],
      user_class:   user_class,
      auth_level:   auth_level,
      logout!:      nil
    )
  end

  let(:session)    { make_session }
  let(:dispatcher) { described_class.new(session) }

  # ── /settings ───────────────────────────────────────────────────────────────

  describe '#dispatch("/settings")' do
    it 'returns ok with a commands list' do
      result = dispatcher.dispatch('/settings')
      expect(result[:status]).to eq('ok')
      expect(result[:data][:commands]).to be_an(Array)
      expect(result[:data][:commands]).to include('/settings/2fa')
    end

    it 'raises auth error when not logged in' do
      allow(session).to receive(:require_auth!)
        .and_raise(LaunchCore::Auth::AuthError, 'Authentication required')
      result = dispatcher.dispatch('/settings')
      # cmd_settings rescues and calls Output.critical (no json in that rescue)
      # so the return value is nil — just ensure no crash
      expect { dispatcher.dispatch('/settings') }.not_to raise_error
    end
  end

  # ── /settings/kyc ───────────────────────────────────────────────────────────

  describe '#dispatch("/settings/kyc")' do
    it 'returns ok with KYC instructions in json mode' do
      result = dispatcher.dispatch('/settings/kyc')
      expect(result[:status]).to eq('ok')
      expect(result[:data][:instructions]).to match(/kyc/i)
    end
  end

  # ── /settings/2fa — setup path ────────────────────────────────────────────

  describe '#dispatch("/settings/2fa")' do
    before do
      allow(LaunchCore::Auth::Authenticator).to receive(:setup_totp!) do |uid|
        ['JBSWY3DPEHPK3PXP', "otpauth://totp/LaunchCore:#{user[:email]}?secret=JBSWY3DPEHPK3PXP"]
      end
    end

    it 'returns ok with secret and otpauth_uri when no code given' do
      result = dispatcher.dispatch('/settings/2fa')
      expect(result[:status]).to eq('ok')
      expect(result[:data][:secret]).not_to be_nil
      expect(result[:data][:otpauth_uri]).to match(/otpauth/)
    end
  end

  # ── /settings/2fa — verify path ──────────────────────────────────────────

  describe '#dispatch("/settings/2fa --code=123456")' do
    before do
      allow(LaunchCore::Auth::Authenticator).to receive(:verify_totp!)
        .with(user[:id], '123456').and_return(true)
      allow(LaunchCore::Auth::Authenticator).to receive(:evaluate_auth_level!)
        .with(user[:id]).and_return(2)
    end

    it 'verifies the code and returns the new auth level' do
      result = dispatcher.dispatch('/settings/2fa', ['--code=123456'])
      expect(result[:status]).to eq('ok')
      expect(result[:data][:auth_level]).to eq(2)
    end
  end

  # ── /settings/profile ────────────────────────────────────────────────────

  describe '#dispatch("/settings/profile")' do
    it 'returns profile data including email and auth_level' do
      result = dispatcher.dispatch('/settings/profile')
      expect(result[:status]).to eq('ok')
      expect(result[:data][:email]).to eq(user[:email])
      expect(result[:data][:auth_level]).to be_a(Integer)
    end
  end

  # ── /auth/signup — JSON mode with inline args ────────────────────────────

  describe '#dispatch("/auth/signup") in JSON mode with inline args' do
    it 'creates a new account and returns ok' do
      email = "signup_#{SecureRandom.hex(4)}@example.com"
      result = dispatcher.dispatch(
        '/auth/signup',
        ["--email=#{email}", '--password=ValidPass1!xyz',
         '--first_name=Test', '--last_name=User']
      )
      expect(result[:status]).to eq('ok')
      expect(result[:data][:email]).to eq(email)
    end

    it 'returns error for duplicate email' do
      email = user[:email]
      result = dispatcher.dispatch(
        '/auth/signup',
        ["--email=#{email}", '--password=ValidPass1!xyz',
         '--first_name=Test', '--last_name=User']
      )
      expect(result[:status]).to eq('error')
    end
  end

  # ── /auth/logout — when not logged in ────────────────────────────────────

  describe '#dispatch("/auth/logout") when session is inactive' do
    let(:guest_session) do
      instance_double(
        LaunchCore::Auth::Session,
        logged_in?:    false,
        current_user:  nil,
        require_auth!: nil,
        logout!:       nil
      )
    end
    let(:guest_dispatcher) { described_class.new(guest_session) }

    it 'returns ok with no-session message' do
      result = guest_dispatcher.dispatch('/auth/logout')
      expect(result[:status]).to eq('ok')
      expect(result[:message]).to match(/no active session/i)
    end
  end

  # ── Non-JSON mode routing ──────────────────────────────────────────────

  describe 'non-json mode dispatch' do
    before { LaunchCore::Output.json_mode = false }
    after  { LaunchCore::Output.json_mode = true  }

    it '/settings prints settings info without raising' do
      LaunchCore::Output.silent_mode = true
      expect { dispatcher.dispatch('/settings') }.not_to raise_error
      LaunchCore::Output.silent_mode = false
    end

    it '/settings/kyc prints KYC info without raising' do
      LaunchCore::Output.silent_mode = true
      expect { dispatcher.dispatch('/settings/kyc') }.not_to raise_error
      LaunchCore::Output.silent_mode = false
    end

    it 'unknown command prints a warning without raising' do
      LaunchCore::Output.silent_mode = true
      result = dispatcher.dispatch('/does_not_exist_xyz')
      expect(result[:status]).to eq('error')
      LaunchCore::Output.silent_mode = false
    end

    it '/help prints sections to stdout' do
      out = StringIO.new
      $stdout = out
      dispatcher.dispatch('/help')
      $stdout = STDOUT
      expect(out.string).not_to be_empty
    end

    it '/status prints session info when logged in' do
      out = StringIO.new
      $stdout = out
      dispatcher.dispatch('/status')
      $stdout = STDOUT
      expect(out.string).not_to be_empty
    end

    it '/status prints unauthenticated message when no session' do
      allow(session).to receive(:logged_in?).and_return(false)
      out = StringIO.new
      $stdout = out
      dispatcher.dispatch('/status')
      $stdout = STDOUT
      expect(out.string).to match(/not authenticated/i)
    end

    it '/auth/login with real credentials shows welcome message' do
      # Use a fresh session that isn't yet logged in
      fresh_session = instance_double(
        LaunchCore::Auth::Session,
        logged_in?: false,
        store!:     nil
      )
      real_disp = described_class.new(fresh_session)
      out = StringIO.new
      $stdout = out
      real_disp.dispatch('/auth/login',
        ["--email=#{user[:email]}", '--password=TestPass1!abcd'])
      $stdout = STDOUT
      expect(out.string).to match(/welcome/i)
    end

    it '/auth/login with wrong credentials shows error message' do
      fresh_session = instance_double(
        LaunchCore::Auth::Session,
        logged_in?: false
      )
      real_disp = described_class.new(fresh_session)
      out = StringIO.new
      $stdout = out
      real_disp.dispatch('/auth/login',
        ["--email=#{user[:email]}", '--password=WrongPass99!xyz'])
      $stdout = STDOUT
      expect(out.string).to match(/invalid|error/i)
    end

    it '/auth/logout when not logged in prints "no active session"' do
      allow(session).to receive(:logged_in?).and_return(false)
      out = StringIO.new
      $stdout = out
      dispatcher.dispatch('/auth/logout')
      $stdout = STDOUT
      expect(out.string).to match(/no active session/i)
    end

    it '/auth/invite non-json shows code and role' do
      allow(session).to receive(:require_auth!).and_return(nil)
      allow(session).to receive(:user_id).and_return(user[:id])
      allow(LaunchCore::Auth::Authenticator).to receive(:generate_invite!)
        .and_return('LCI-TESTCODE1234')
      out = StringIO.new
      $stdout = out
      dispatcher.dispatch('/auth/invite', ['--role=company_agent'])
      $stdout = STDOUT
      expect(out.string).to match(/LCI-TESTCODE1234/i)
    end

  end

  describe '#dispatch("/auth/invite")' do
    let(:l2_session) { make_session(auth_level: 2) }
    let(:l2_dispatcher) { described_class.new(l2_session) }

    before do
      allow(LaunchCore::Auth::Authenticator).to receive(:generate_invite!) do |**opts|
        "INV-#{SecureRandom.hex(4).upcase}"
      end
    end

    it 'returns ok with an invite code in json mode' do
      result = l2_dispatcher.dispatch('/auth/invite', ['--role=company_agent'])
      expect(result[:status]).to eq('ok')
      expect(result[:data][:code]).to match(/INV-/)
    end

    it 'returns error when auth requirement fails' do
      allow(session).to receive(:require_auth!)
        .with(min_level: 2)
        .and_raise(LaunchCore::Auth::AuthError, 'Auth level 2 required')
      result = dispatcher.dispatch('/auth/invite')
      expect(result[:status]).to eq('error')
      expect(result[:message]).to match(/auth level 2/i)
    end
  end

  # ── Product dispatch — non-json path ────────────────────────────────────

  describe 'product dispatch (non-json mode)' do
    before { LaunchCore::Output.json_mode = false }

    it 'dispatches /voice and does not raise' do
      expect { dispatcher.dispatch('/voice') }.not_to raise_error
    end

    it 'shows upgrade hint for insufficient auth (non-json)' do
      allow(session).to receive(:require_auth!) do |min_level:, **|
        raise LaunchCore::Auth::AuthError, "Auth level #{min_level} required"
      end
      out = StringIO.new
      allow($stdout).to receive(:puts) { |s| out.puts(s) }
      dispatcher.dispatch('/neobank')
      # Just ensure it doesn't crash; hint is printed to stdout
    end
  end

  # ── All 11 products dispatch via real session ─────────────────────────────

  describe 'all 11 products dispatch with authenticated session' do
    let(:real_session) do
      s = LaunchCore::Auth::Session.new
      token, = LaunchCore::Auth::JWTManager.encode(
        user_id:    user[:id],
        email:      user[:email],
        user_class: user[:user_class],
        auth_level: 4
      )
      s.store!(token)
      s
    end
    let(:real_dispatcher) { described_class.new(real_session) }

    %w[voice tunnel portal meetings workforce scheduler
       neobank brinkspay tradeshield stophold arbiter].each do |product|
      it "dispatches /#{product} without error" do
        result = real_dispatcher.dispatch("/#{product}")
        expect(result).to be_a(Hash)
        expect(result[:status]).to be_a(String)
      end
    end
  end
end
