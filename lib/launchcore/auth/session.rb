# frozen_string_literal: true

require 'json'
require 'fileutils'

module LaunchCore
  module Auth
    # Shared error class — accessible as both LaunchCore::Auth::AuthError
    # and LaunchCore::Auth::Session::AuthError (for test doubles compatibility).
    class AuthError < StandardError; end

    # Manages the on-disk session file (~/.lcl_session) and in-memory state
    class Session
      # Expose AuthError as a nested constant so specs can reference it as Session::AuthError
      AuthError = LaunchCore::Auth::AuthError

      attr_reader :token, :claims

      def initialize
        @token  = nil
        @claims = nil
      end

      # -------- Public interface --------

      def authenticated?
        return false if @claims.nil?
        return false if expired?

        true
      end

      alias logged_in? authenticated?

      def current_user
        return nil unless authenticated?

        @claims
      end

      def user_id     = @claims&.fetch('sub', nil)&.to_i
      def email       = @claims&.fetch('email', nil)
      def user_class  = @claims&.fetch('user_class', nil)
      def auth_level  = @claims&.fetch('auth_level', 1)

      def entitlements
        raw = @claims&.fetch('entitlements', '{}') || '{}'
        raw.is_a?(Hash) ? raw : JSON.parse(raw)
      rescue JSON::ParseError
        {}
      end

      def store!(token)
        @token  = token
        @claims = JWTManager.decode(token)
        persist_to_disk!(token)
      end

      def destroy!
        jti = @claims&.fetch('jti', nil)
        JWTManager.revoke!(jti) if jti
        @token  = nil
        @claims = nil
        purge_disk!
      end

      alias logout! destroy!

      # Called on REPL startup — restores session from ~/.lcl_session if valid
      def auto_resume
        # Priority 1: Environment Variable (Used by Robot/Automation)
        env_token = ENV.fetch('LCL_SESSION_TOKEN', nil)
        if env_token && !env_token.empty?
          @token  = env_token
          @claims = JWTManager.decode(env_token)
          return true
        end

        # Priority 2: Disk Cache
        return false unless File.exist?(Config::SESSION_FILE)

        token = File.read(Config::SESSION_FILE).strip
        return false if token.empty?

        @token  = token
        @claims = JWTManager.decode(token)
        Output.info("Session restored for #{email}")
        true
      rescue StandardError => e
        Output.muted("Could not resume session: #{e.message}")
        purge_disk!
        false
      end

      # -------- Auth level checks --------

      # rubocop:disable Naming/PredicateMethod
      def require_auth!(min_level: 1, min_class: :any)
        raise AuthError, 'Authentication required. Use /auth/login' unless authenticated?

        unless auth_level >= min_level
          raise AuthError,
                "This feature requires Auth Level #{min_level} " \
                "(#{Config::AUTH_LEVELS[min_level]}). " \
                "Your current level: L#{auth_level}."
        end

        if (min_class != :any) && !class_satisfies?(min_class)
          raise AuthError,
                "This feature requires class: #{Config::USER_CLASSES[min_class.to_s]}. " \
                "Your class: #{Config::USER_CLASSES[user_class] || user_class}"
        end

        true
      end
      # rubocop:enable Naming/PredicateMethod

      private

      def expired?
        exp = @claims&.fetch('exp', nil)
        return true if exp.nil?

        Time.now.to_i >= exp
      end

      def class_satisfies?(required_class)
        hierarchy = { 'power_user' => 0, 'company_agent' => 1, 'company' => 2 }
        (hierarchy[user_class] || 0) >= (hierarchy[required_class.to_s] || 0)
      end

      def persist_to_disk!(token)
        FileUtils.mkdir_p(File.dirname(Config::SESSION_FILE))
        File.write(Config::SESSION_FILE, token)
        FileUtils.chmod(0o600, Config::SESSION_FILE)
      end

      def purge_disk!
        FileUtils.rm_f(Config::SESSION_FILE)
      end
    end
  end
end
