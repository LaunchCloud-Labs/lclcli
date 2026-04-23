# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'time'
require 'securerandom'

require_relative 'launchcore/version'
require_relative 'launchcore/config'
require_relative 'launchcore/output'
require_relative 'launchcore/database'
require_relative 'launchcore/mailer'
require_relative 'launchcore/auth/jwt_manager'
require_relative 'launchcore/auth/session'
require_relative 'launchcore/auth/authenticator'
require_relative 'launchcore/cli/splash'
require_relative 'launchcore/cli/dispatcher'
require_relative 'launchcore/cli/repl'
require_relative 'launchcore/products/base'
require_relative 'launchcore/products/registry'
require_relative 'launchcore/products/voice'
require_relative 'launchcore/products/tunnel'
require_relative 'launchcore/products/portal'
require_relative 'launchcore/products/neural_meetings'
require_relative 'launchcore/products/workforce'
require_relative 'launchcore/products/scheduler'
require_relative 'launchcore/products/neobank'
require_relative 'launchcore/products/brinkspay'
require_relative 'launchcore/products/tradeshield'
require_relative 'launchcore/products/stophold'
require_relative 'launchcore/products/arbiter'

module LaunchCore
  class Error < StandardError; end

  def self.boot!
    Config.ensure_local_dirs!
    Auth::JWTManager.generate_keys! unless Auth::JWTManager.keys_exist?
    Database.connect!
  end
end
