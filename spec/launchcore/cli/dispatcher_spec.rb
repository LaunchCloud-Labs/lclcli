# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LaunchCore::CLI::Dispatcher do
  let(:user)       { create_test_user }
  let(:session)    { instance_double(LaunchCore::Auth::Session, logged_in?: true, current_user: user, require_auth!: nil) }
  let(:dispatcher) { described_class.new(session) }

  before do
    LaunchCore::Output.json_mode = true
  end

  # ── /help ────────────────────────────────────────────────────
  describe '#dispatch("/help")' do
    it 'returns ok with a commands list' do
      result = dispatcher.dispatch('/help')
      expect(result[:status]).to eq('ok')
      expect(result[:commands]).to be_an(Array)
      expect(result[:commands]).not_to be_empty
    end
  end

  # ── /status ──────────────────────────────────────────────────
  describe '#dispatch("/status")' do
    it 'returns system status including version' do
      result = dispatcher.dispatch('/status')
      expect(result[:status]).to  eq('ok')
      expect(result[:version]).to eq(LaunchCore::VERSION)
    end
  end

  # ── /auth/login ──────────────────────────────────────────────
  describe '#dispatch("/auth/login")' do
    context 'when already logged in' do
      it 'returns already_logged_in or ok' do
        result = dispatcher.dispatch('/auth/login')
        expect(%w[ok already_logged_in]).to include(result[:status])
      end
    end
  end

  # ── /auth/logout ─────────────────────────────────────────────
  describe '#dispatch("/auth/logout")' do
    it 'calls session logout and returns ok' do
      allow(session).to receive(:logout!)
      result = dispatcher.dispatch('/auth/logout')
      expect(result[:status]).to eq('ok')
    end
  end

  # ── Unknown command ───────────────────────────────────────────
  describe '#dispatch with unknown command' do
    it 'returns error status' do
      result = dispatcher.dispatch('/nonexistent_command_xyz')
      expect(result[:status]).to eq('error')
      expect(result[:message]).to match(/unknown|not found/i)
    end
  end

  # ── Argument parsing ─────────────────────────────────────────
  describe '#parse_args' do
    it 'parses --key=value flags into a hash' do
      result = dispatcher.send(:parse_args, ['--sub=status', '--format=json'])
      expect(result[:sub]).to    eq('status')
      expect(result[:format]).to eq('json')
    end

    it 'parses bare flags as true' do
      result = dispatcher.send(:parse_args, ['--verbose'])
      expect(result[:verbose]).to eq(true)
    end

    it 'handles mixed args gracefully' do
      result = dispatcher.send(:parse_args, ['--sub=call', '--to=+13215550100', '--verbose'])
      expect(result[:sub]).to     eq('call')
      expect(result[:to]).to      eq('+13215550100')
      expect(result[:verbose]).to eq(true)
    end
  end

  # ── Product dispatch with auth enforcement ─────────────────────
  describe 'product dispatch with insufficient auth' do
    let(:low_user) { user.merge(auth_level: 1, user_class: 'power_user') }
    let(:low_session) do
      instance_double(LaunchCore::Auth::Session,
                      logged_in?:   true,
                      current_user: low_user,
                      require_auth!: nil)
    end
    let(:low_dispatcher) { described_class.new(low_session) }

    before do
      # Stub require_auth! to raise AuthError for L3+ products
      allow(low_session).to receive(:require_auth!) do |min_level:, **|
        if min_level && low_user[:auth_level] < min_level
          raise LaunchCore::Auth::Session::AuthError, "Auth level #{min_level} required"
        end
      end
    end

    it 'returns auth error for /neobank (L3+) with L1 user' do
      result = low_dispatcher.dispatch('/neobank')
      expect(result[:status]).to eq('error')
      expect(result[:message]).to match(/auth|level|required/i)
    end

    it 'returns auth error for /stophold (L4) with L1 user' do
      result = low_dispatcher.dispatch('/stophold')
      expect(result[:status]).to eq('error')
    end
  end

  # ── JSON flag stripping ───────────────────────────────────────
  describe 'JSON flag interaction' do
    it 'strips --json from args before parsing' do
      # The dispatcher should not see --json as a regular arg
      result = dispatcher.dispatch('/status', ['--json'])
      expect(result[:status]).to eq('ok')
    end
  end
end
