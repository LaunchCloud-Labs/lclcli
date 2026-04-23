# frozen_string_literal: true

require 'spec_helper'

# Sinatra / Rack testing
ENV['RACK_ENV'] = 'test'

# We need to load the Sinatra app. Set LC_BIN to exe/lc path.
ENV['LC_BIN'] = File.expand_path('../../exe/lc', __dir__)

require_relative '../../sinatra/app'

RSpec.describe 'Sinatra web bridge', type: :request do
  def app
    LaunchCoreApp
  end

  # ── Public routes ─────────────────────────────────────────────
  describe 'GET /' do
    it 'returns 200 or redirect to /dashboard' do
      get '/'
      expect([200, 301, 302]).to include(last_response.status)
    end
  end

  describe 'GET /login' do
    it 'renders the login page with 200' do
      get '/login'
      expect(last_response).to be_ok
      expect(last_response.body).to include('Sign In')
    end
  end

  describe 'GET /signup' do
    it 'renders the signup page with 200' do
      get '/signup'
      expect(last_response).to be_ok
      expect(last_response.body).to include('Create Account')
    end
  end

  # ── Auth enforcement ──────────────────────────────────────────
  describe 'GET /dashboard without session' do
    it 'redirects to /login' do
      get '/dashboard'
      expect(last_response).to be_redirect
      expect(last_response.location).to include('/login')
    end
  end

  # ── /api/exec security whitelist ──────────────────────────────
  describe 'POST /api/exec' do
    context 'without session cookie' do
      it 'returns 401' do
        post '/api/exec', JSON.generate({ command: '/status' }),
             { 'CONTENT_TYPE' => 'application/json' }
        expect(last_response.status).to eq(401)
      end
    end

    context 'with a session cookie and a valid whitelisted command' do
      before do
        # Stub the session helper to fake authentication
        allow_any_instance_of(LaunchCoreApp).to receive(:current_web_user)
          .and_return({ id: 1, email: 'test@example.com', auth_level: 2 })
        allow_any_instance_of(LaunchCoreApp).to receive(:logged_in?).and_return(true)
        allow_any_instance_of(LaunchCoreApp).to receive(:session_token).and_return('fake.jwt.token')
      end

      it 'rejects a blacklisted command' do
        post '/api/exec', JSON.generate({ command: '/auth/login' }),
             { 'CONTENT_TYPE' => 'application/json' }
        json = JSON.parse(last_response.body)
        expect(json['status']).to eq('error')
        expect(json['message']).to match(/not allowed/i)
      end
    end
  end

  # ── /api/status ───────────────────────────────────────────────
  describe 'GET /api/status' do
    it 'returns JSON with status ok' do
      get '/api/status'
      expect(last_response.status).to eq(200)
      json = JSON.parse(last_response.body)
      expect(json['status']).to eq('ok')
    end
  end
end
