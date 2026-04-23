# frozen_string_literal: true

require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new(:rubocop)

task default: %i[rubocop spec]

desc 'Run linter only'
task :lint do
  Rake::Task[:rubocop].invoke
end

desc 'Run full test suite'
task :test do
  Rake::Task[:spec].invoke
end

desc 'Initialize DB and generate keys'
task :setup do
  require_relative 'lib/launchcore'
  LaunchCore.boot!
  puts 'LaunchCore setup complete.'
end

desc 'Show version'
task :version do
  require_relative 'lib/launchcore/version'
  puts "LaunchCore v#{LaunchCore::VERSION} \"#{LaunchCore::CODENAME}\""
end
