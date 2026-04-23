# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  minimum_coverage 70
end

require 'bundler/setup'
require 'rspec'
require 'rack/test'
require 'timecop'
require 'tmpdir'

# Point to test environment BEFORE loading the library
ENV['LCL_ROOT'] = Dir.mktmpdir('lcl_test')
ENV['HOME']     = Dir.mktmpdir('lcl_home')

require 'launchcore'
require 'mail'

# Force test-mode mail delivery (no sendmail calls in tests)
Mail.defaults { delivery_method :test }

# Apply schema to the test DB
LaunchCore.boot!

Dir[File.join(__dir__, 'support', '**', '*.rb')].sort.each { |f| require f }

RSpec.configure do |config|
  config.include Rack::Test::Methods, type: :request
  config.include DatabaseHelper

  # Use expect syntax only
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.mock_with(:rspec)   { |c| c.verify_partial_doubles = true }

  # Human-readable output
  config.formatter = :documentation

  # Suppress output during tests
  config.before(:suite) do
    LaunchCore::Output.json_mode = true
  end

  # Clean DB between tests at the suite (not example) level using truncation
  config.before(:each) do
    truncate_tables!
  end

  config.after(:suite) do
    Timecop.return
    # Clean up temp dirs
    FileUtils.rm_rf(ENV['LCL_ROOT'])
    FileUtils.rm_rf(ENV['HOME'])
  end
end
