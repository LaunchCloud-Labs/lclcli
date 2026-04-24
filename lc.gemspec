# frozen_string_literal: true

require_relative 'lib/launchcore/version'

Gem::Specification.new do |spec|
  spec.name          = 'launchcore'
  spec.version       = LaunchCore::VERSION
  spec.authors       = ['LaunchCloud Labs']
  spec.email         = ['engineering@launchcloudlabs.com']

  spec.summary       = 'LaunchCore Command — The Unified CLI for the LaunchCloud Labs Platform'
  spec.description   = <<~DESC
    LaunchCore Command (lc) is the CLI-first foundation for the entire LaunchCloud Labs
    11-product stack. It provides an interactive REPL, RS256 JWT authentication, 4-tier
    auth levels, and a Sinatra web mirror — all backed by a single SQLite source of truth.
  DESC
  spec.homepage = 'https://launchcloudlabs.com'
  spec.license               = 'Nonstandard'
  spec.required_ruby_version = '>= 3.0'

  spec.metadata = {
    'homepage_uri' => spec.homepage,
    'source_code_uri' => 'https://github.com/LaunchCloudLabs/launchcore-cli',
    'rubygems_mfa_required' => 'true'
  }

  spec.files = Dir.glob('{lib,exe,sinatra}/**/*', File::FNM_DOTMATCH)
                  .reject { |f| File.directory?(f) }
                  .push('lc.gemspec', 'Gemfile', 'README.md')

  spec.bindir        = 'exe'
  spec.executables   = ['lc']
  spec.require_paths = ['lib']

  # ── Runtime dependencies ──────────────────────────────────────────────
  spec.add_dependency 'bcrypt',           '~> 3.1'
  spec.add_dependency 'jwt',              '~> 2.9'
  spec.add_dependency 'mail',             '~> 2.8'
  spec.add_dependency 'puma',             '>= 6.4'
  spec.add_dependency 'rack-protection',  '~> 4.0'
  spec.add_dependency 'rotp',             '~> 6.3'
  spec.add_dependency 'sequel',           '~> 5.80'
  spec.add_dependency 'sinatra',          '~> 4.0'
  spec.add_dependency 'sinatra-contrib',  '~> 4.0'
  spec.add_dependency 'sqlite3',          '~> 1.7'

  # ── Development dependencies ─────────────────────────────────────────
  # rubocop:disable Gemspec/DevelopmentDependencies
  spec.add_development_dependency 'rack-test',     '~> 2.1'
  spec.add_development_dependency 'rspec',         '~> 3.13'
  spec.add_development_dependency 'rubocop',       '~> 1.65'
  spec.add_development_dependency 'rubocop-rspec', '~> 3.1'
  spec.add_development_dependency 'simplecov',     '~> 0.22'
  spec.add_development_dependency 'timecop',       '~> 0.9'
  # rubocop:enable Gemspec/DevelopmentDependencies
end
