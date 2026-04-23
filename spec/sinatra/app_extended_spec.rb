# frozen_string_literal: true

require 'spec_helper'

ENV['RACK_ENV'] = 'test'
ENV['LC_BIN']   = File.expand_path('../../exe/lc', __dir__)

require_relative '../../sinatra/app'

RSpec.describe 'Sinatra web bridge (extended)', type: :request do
  include DatabaseHelper

  def app
    LaunchCoreApp
  end

  before(:each) { truncate_tables! }

  # ── POST /login — wrong credentials ──────────────────────────────────────

  describe 'POST /login with bad credentials' do
    it 'renders login page with an error' do
      post '/login', email: 'nobody@example.com', password: 'WrongPass1!'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Sign In')
    end
  end

  # ── POST /login — valid credentials ──────────────────────────────────────

  describe 'POST /login with valid credentials' do
    let!(:user) { create_test_user(email: 'web@example.com', password: 'TestPass1!abcd') }

    it 'redirects to /dashboard on success' do
      post '/login', email: 'web@example.com', password: 'TestPass1!abcd'
      expect(last_response.status).to be_between(301, 302)
      expect(last_response.location).to include('/dashboard')
    end
  end

  # ── POST /signup — password mismatch ────────────────────────────────────

  describe 'POST /signup with mismatched passwords' do
    it 'renders signup page with an error' do
      post '/signup',
           email:            "new#{SecureRandom.hex(4)}@example.com",
           first_name:       'New',
           last_name:        'User',
           password:         'TestPass1!abcd',
           password_confirm: 'DifferentPass99!'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('do not match')
    end
  end

  # ── POST /signup — valid new user ─────────────────────────────────────────

  describe 'POST /signup with valid data' do
    it 'creates user and redirects to /dashboard' do
      post '/signup',
           email:            "signup#{SecureRandom.hex(4)}@example.com",
           first_name:       'Fresh',
           last_name:        'User',
           password:         'ValidPass1!xyz',
           password_confirm: 'ValidPass1!xyz'
      expect(last_response.status).to be_between(301, 302)
      expect(last_response.location).to include('/dashboard')
    end
  end

  # ── GET /logout ───────────────────────────────────────────────────────────

  describe 'GET /logout' do
    it 'clears the session and redirects to /' do
      get '/logout'
      expect(last_response).to be_redirect
      expect(last_response.location).to include('/')
    end
  end

  # ── GET /dashboard with session ───────────────────────────────────────────

  describe 'GET /dashboard with active session' do
    before do
      allow_any_instance_of(LaunchCoreApp).to receive(:logged_in?).and_return(true)
      allow_any_instance_of(LaunchCoreApp).to receive(:current_web_user)
        .and_return({ id: 1, email: 'dash@example.com', auth_level: 1,
                      first_name: 'Test', user_class: 'power_user' })
      # Stub the CLI bridge so no shell-out happens in tests
      allow_any_instance_of(LaunchCoreApp).to receive(:lc_exec)
        .and_return({ 'status' => 'ok', 'data' => { 'auth_level' => 1 } })
    end

    it 'renders the dashboard with 200' do
      get '/dashboard'
      expect(last_response.status).to eq(200)
    end
  end

  # ── POST /api/exec — whitelisted command executes ────────────────────────

  describe 'POST /api/exec with whitelisted command' do
    before do
      allow_any_instance_of(LaunchCoreApp).to receive(:logged_in?).and_return(true)
      allow_any_instance_of(LaunchCoreApp).to receive(:current_web_user)
        .and_return({ id: 1, email: 'test@example.com', auth_level: 2 })
      allow_any_instance_of(LaunchCoreApp).to receive(:session_token)
        .and_return('fake.jwt.token')
      # Stub Open3 so we don't actually shell out
      allow(Open3).to receive(:capture3).and_return(
        ['{"status":"ok","message":"Help"}', '', double(exitstatus: 0)]
      )
    end

    it 'executes a whitelisted command and returns JSON' do
      post '/api/exec', JSON.generate({ command: '/help' }),
           { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(200)
      json = JSON.parse(last_response.body)
      expect(json['status']).to eq('ok')
    end
  end

  # ── GET /api/status payload ───────────────────────────────────────────────

  describe 'GET /api/status full payload' do
    it 'includes version and authenticated fields' do
      get '/api/status'
      json = JSON.parse(last_response.body)
      expect(json['version']).to eq(LaunchCore::VERSION)
      expect(json).to have_key('authenticated')
      expect(json).to have_key('time')
    end
  end

  # ── 404 handler ──────────────────────────────────────────────────────────

  describe 'GET /nonexistent_route' do
    it 'returns 404' do
      get '/nonexistent_route_xyz'
      expect(last_response.status).to eq(404)
    end
  end

  # ── API 404 ───────────────────────────────────────────────────────────────

  describe 'GET /api/nonexistent' do
    it 'returns 404 JSON for API paths' do
      get '/api/nonexistent'
      expect(last_response.status).to eq(404)
      json = JSON.parse(last_response.body)
      expect(json['status']).to eq('error')
    end
  end
end
