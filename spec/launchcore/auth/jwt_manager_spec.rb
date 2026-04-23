# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LaunchCore::Auth::JWTManager do
  include DatabaseHelper

  before(:each) { truncate_tables! }

  let(:user) { create_test_user }

  describe '.keys_exist?' do
    it 'returns true when keys are present' do
      expect(described_class.keys_exist?).to be true
    end
  end

  describe '.private_key and .public_key' do
    it 'returns an RSA private key' do
      expect(described_class.private_key).to be_a(OpenSSL::PKey::RSA)
      expect(described_class.private_key.private?).to be true
    end

    it 'returns an RSA public key' do
      expect(described_class.public_key).to be_a(OpenSSL::PKey::RSA)
    end
  end

  describe '.encode' do
    it 'returns a [token_string, jti] pair' do
      token, jti = described_class.encode(
        user_id: user[:id], email: user[:email],
        user_class: 'power_user', auth_level: 1
      )
      expect(token).to be_a(String)
      expect(token.split('.').length).to eq(3) # JWT structure
      expect(jti).to match(/\A[0-9a-f-]{36}\z/)
    end

    it 'registers the session in the DB' do
      _, jti = described_class.encode(
        user_id: user[:id], email: user[:email],
        user_class: 'power_user', auth_level: 1
      )
      row = LaunchCore::Database::Models.sessions.where(jti: jti).first
      expect(row).not_to be_nil
      expect(row[:revoked]).to eq(0)
    end
  end

  describe '.decode' do
    let(:token_pair) do
      described_class.encode(
        user_id: user[:id], email: user[:email],
        user_class: 'power_user', auth_level: 1
      )
    end
    let(:token) { token_pair.first }

    it 'decodes a valid token and returns claims' do
      claims = described_class.decode(token)
      expect(claims['email']).to eq(user[:email])
      expect(claims['auth_level']).to eq(1)
      expect(claims['iss']).to eq(LaunchCore::Config::JWT_ISSUER)
    end

    it 'raises on a tampered/invalid token' do
      expect { described_class.decode('garbage.token.here') }
        .to raise_error(RuntimeError, /Invalid token/)
    end

    it 'raises when session is revoked' do
      _, jti = token_pair
      described_class.revoke!(jti)
      expect { described_class.decode(token) }
        .to raise_error(RuntimeError, /revoked/)
    end

    it 'raises on an expired token' do
      expired = JWT.encode(
        { sub: '1', email: 'x@x.com', user_class: 'power_user',
          auth_level: 1, entitlements: {}, iss: LaunchCore::Config::JWT_ISSUER,
          aud: LaunchCore::Config::JWT_AUDIENCE, iat: Time.now.to_i - 7200,
          exp: Time.now.to_i - 3600, jti: SecureRandom.uuid },
        described_class.private_key, 'RS256'
      )
      expect { described_class.decode(expired) }
        .to raise_error(RuntimeError, /expired/)
    end
  end

  describe '.revoke!' do
    it 'marks the session revoked in the DB' do
      _, jti = described_class.encode(
        user_id: user[:id], email: user[:email],
        user_class: 'power_user', auth_level: 1
      )
      described_class.revoke!(jti)
      row = LaunchCore::Database::Models.sessions.where(jti: jti).first
      expect(row[:revoked]).to eq(1)
      expect(row[:revoked_at]).not_to be_nil
    end
  end

  describe '.reset_key_cache!' do
    it 'clears memoized key instances without error' do
      described_class.private_key # memoize
      described_class.public_key  # memoize
      expect { described_class.reset_key_cache! }.not_to raise_error
    end
  end
end
