# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LaunchCore::Auth::Session do
  include DatabaseHelper

  before(:each) { truncate_tables! }

  let(:user)    { create_test_user }
  let(:session) { described_class.new }

  def fresh_token
    token, = LaunchCore::Auth::JWTManager.encode(
      user_id:    user[:id],
      email:      user[:email],
      user_class: user[:user_class],
      auth_level: user[:auth_level]
    )
    token
  end

  describe '#authenticated? / #logged_in?' do
    it 'returns false when no token is stored' do
      expect(session.authenticated?).to be false
      expect(session.logged_in?).to be false
    end

    it 'returns true after storing a valid token' do
      session.store!(fresh_token)
      expect(session.authenticated?).to be true
      expect(session.logged_in?).to be true
    end
  end

  describe '#current_user' do
    it 'returns nil when unauthenticated' do
      expect(session.current_user).to be_nil
    end

    it 'returns the claims hash after login' do
      session.store!(fresh_token)
      cu = session.current_user
      expect(cu).to be_a(Hash)
      expect(cu['email']).to eq(user[:email])
    end
  end

  describe 'claim accessors' do
    before { session.store!(fresh_token) }

    it '#user_id returns integer user id' do
      expect(session.user_id).to eq(user[:id])
    end

    it '#email returns the user email' do
      expect(session.email).to eq(user[:email])
    end

    it '#user_class returns the user class string' do
      expect(session.user_class).to eq('power_user')
    end

    it '#auth_level returns integer level' do
      expect(session.auth_level).to eq(1)
    end

    it '#entitlements returns a hash' do
      expect(session.entitlements).to be_a(Hash)
    end
  end

  describe '#store!' do
    it 'writes the session file to disk' do
      token = fresh_token
      session.store!(token)
      expect(File.exist?(LaunchCore::Config::SESSION_FILE)).to be true
      expect(File.read(LaunchCore::Config::SESSION_FILE).strip).to eq(token)
    end

    it 'sets the session file to mode 600' do
      session.store!(fresh_token)
      mode = File.stat(LaunchCore::Config::SESSION_FILE).mode & 0o777
      expect(mode).to eq(0o600)
    end
  end

  describe '#destroy! / #logout!' do
    it 'clears in-memory state and removes the session file' do
      session.store!(fresh_token)
      session.destroy!
      expect(session.authenticated?).to be false
      expect(File.exist?(LaunchCore::Config::SESSION_FILE)).to be false
    end

    it 'logout! is an alias for destroy!' do
      session.store!(fresh_token)
      session.logout!
      expect(session.authenticated?).to be false
    end
  end

  describe '#auto_resume' do
    context 'when session file exists with a valid token' do
      it 'restores the session and returns true' do
        token = fresh_token
        FileUtils.mkdir_p(File.dirname(LaunchCore::Config::SESSION_FILE))
        File.write(LaunchCore::Config::SESSION_FILE, token)
        new_session = described_class.new
        result = new_session.auto_resume
        expect(result).to be true
        expect(new_session.authenticated?).to be true
      end
    end

    context 'when session file is missing' do
      it 'returns false without raising' do
        FileUtils.rm_f(LaunchCore::Config::SESSION_FILE)
        expect(session.auto_resume).to be false
      end
    end

    context 'when session file contains garbage' do
      it 'returns false and cleans up' do
        FileUtils.mkdir_p(File.dirname(LaunchCore::Config::SESSION_FILE))
        File.write(LaunchCore::Config::SESSION_FILE, 'not.a.jwt')
        expect(session.auto_resume).to be false
        expect(File.exist?(LaunchCore::Config::SESSION_FILE)).to be false
      end
    end
  end

  describe '#require_auth!' do
    context 'when not authenticated' do
      it 'raises AuthError' do
        expect { session.require_auth! }
          .to raise_error(LaunchCore::Auth::AuthError, /Authentication required/)
      end
    end

    context 'when authenticated with L1' do
      before { session.store!(fresh_token) }

      it 'passes for min_level: 1' do
        expect { session.require_auth!(min_level: 1) }.not_to raise_error
      end

      it 'raises AuthError for min_level: 2' do
        expect { session.require_auth!(min_level: 2) }
          .to raise_error(LaunchCore::Auth::AuthError, /Auth Level 2/)
      end

      it 'raises AuthError when class does not match' do
        expect { session.require_auth!(min_class: :company) }
          .to raise_error(LaunchCore::Auth::AuthError, /class/)
      end
    end
  end

  describe 'AuthError constant accessibility' do
    it 'is accessible as Session::AuthError' do
      expect(described_class::AuthError).to eq(LaunchCore::Auth::AuthError)
    end
  end
end
