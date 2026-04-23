# frozen_string_literal: true

# LaunchCore Rack entry point — Phusion Passenger / Puma
# Serves the Sinatra web bridge from /home/Gcolonna/public_html/lclcli

ENV['LCL_ROOT'] ||= File.dirname(__FILE__)

$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
require_relative 'sinatra/app'

run LaunchCoreApp
