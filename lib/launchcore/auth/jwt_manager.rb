# frozen_string_literal: true

require 'jwt'
require 'openssl'
require 'securerandom'
require 'fileutils'

module LaunchCore
  module Auth
    class JWTManager
      ALG = Config::JWT_ALGORITHM
      EXP = Config::JWT_EXPIRY
      ISS = Config::JWT_ISSUER
      AUD = Config::JWT_AUDIENCE

      class << self
        # ---------- Key management ----------

        # rubocop:disable Naming/PredicateMethod
        def generate_keys!
          FileUtils.mkdir_p(Config::KEYS_DIR) unless File.directory?(Config::KEYS_DIR)
          rsa = OpenSSL::PKey::RSA.generate(2048)
          File.write(Config::PRIVATE_KEY, rsa.to_pem)
          File.write(Config::PUBLIC_KEY, rsa.public_key.to_pem)
          FileUtils.chmod(0o600, Config::PRIVATE_KEY)
          FileUtils.chmod(0o644, Config::PUBLIC_KEY)
          Output.success("RS256 key pair generated at #{Config::KEYS_DIR}")
          true
        end
        # rubocop:enable Naming/PredicateMethod

        def keys_exist?
          File.exist?(Config::PRIVATE_KEY) && File.exist?(Config::PUBLIC_KEY)
        end

        def private_key
          @private_key ||= OpenSSL::PKey::RSA.new(File.read(Config::PRIVATE_KEY))
        rescue Errno::ENOENT
          raise 'RS256 private key not found. Run `lc setup` first.'
        end

        def public_key
          @public_key ||= OpenSSL::PKey::RSA.new(File.read(Config::PUBLIC_KEY))
        rescue Errno::ENOENT
          raise 'RS256 public key not found. Run `lc setup` first.'
        end

        def reset_key_cache!
          @private_key = nil
          @public_key  = nil
        end

        # ---------- Token operations ----------

        def encode(user_id:, email:, user_class:, auth_level:, entitlements: {})
          jti = SecureRandom.uuid
          now = Time.now.to_i
          payload = {
            sub: user_id.to_s,
            email: email,
            user_class: user_class,
            auth_level: auth_level,
            entitlements: entitlements,
            iss: ISS,
            aud: AUD,
            iat: now,
            exp: now + EXP,
            jti: jti
          }
          token = JWT.encode(payload, private_key, ALG)
          register_session!(jti: jti, user_id: user_id, exp: now + EXP)
          [token, jti]
        end

        def decode(token)
          payload, = JWT.decode(
            token, public_key, true,
            algorithms: [ALG],
            verify_iss: true,
            iss: ISS,
            verify_aud: true,
            aud: AUD,
            verify_expiration: true
          )
          raise 'Session revoked' if session_revoked?(payload['jti'])

          payload
        rescue JWT::ExpiredSignature
          raise 'Session expired. Please log in again.'
        rescue JWT::DecodeError => e
          raise "Invalid token: #{e.message}"
        end

        def revoke!(jti)
          Database::Models.sessions.where(jti: jti).update(
            revoked: 1,
            revoked_at: Time.now.utc.iso8601
          )
        end

        private

        def register_session!(jti:, user_id:, exp:)
          Database::Models.sessions.insert(
            jti: jti,
            user_id: user_id,
            created_at: Time.now.utc.iso8601,
            expires_at: Time.at(exp).utc.iso8601,
            revoked: 0
          )
        rescue Sequel::UniqueConstraintViolation
          nil # Already registered (shouldn't happen with UUID)
        end

        def session_revoked?(jti)
          return false if jti.nil?

          row = Database::Models.sessions.where(jti: jti).first
          row.nil? || row[:revoked] == 1
        end
      end
    end
  end
end
