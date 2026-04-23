# frozen_string_literal: true

# LaunchCore Command — Sinatra Web Bridge
# Every route either renders a view or executes `lc [command] --json`
# via Open3.capture3, returning JSON to the browser.

require 'sinatra/base'
require 'sinatra/json'
require 'sinatra/contrib'
require 'open3'
require 'json'
require 'bcrypt'
require 'securerandom'
require 'fileutils'

$LOAD_PATH.unshift(File.expand_path('../../lib', __dir__))
require 'launchcore'

# ─── Boot ──────────────────────────────────────────────────────────────
LaunchCore.boot!

LC_BIN = ENV.fetch('LC_BIN', File.expand_path('../../exe/lc', __dir__))
LC_ENV = { 'LCL_ROOT' => LaunchCore::Config::LCL_ROOT }.freeze

class LaunchCoreApp < Sinatra::Base
  # ─── Sinatra config ────────────────────────────────────────────────────
  configure do
    set :root,          __dir__
    set :views,         File.join(__dir__, 'views')
    set :public_folder, File.join(__dir__, 'public')
    set :sessions,      true
    set :session_secret, ENV.fetch('LC_SESSION_SECRET') { SecureRandom.hex(64) }
    set :protection, except: :json_csrf
    set :show_exceptions, development?
  end

  # ─── Helpers ────────────────────────────────────────────────────────────
  # rubocop:disable Metrics/BlockLength
  helpers do
    # Execute lc binary and return parsed JSON
    def lc_exec(command, extra_env: {})
      env = LC_ENV.merge(extra_env)
      stdout, stderr, _status = Open3.capture3(env, "#{LC_BIN} #{command} --json")
      raw = stdout.strip
      raw = stderr.strip if raw.empty?
      begin
        JSON.parse(raw, symbolize_names: true)
      rescue JSON::ParseError
        { status: 'error', message: raw.empty? ? 'No output from CLI' : raw }
      end
    end

    # Current session user (from cookie-backed DB session)
    def current_web_user
      return nil unless session[:user_id]

      LaunchCore::Database::Models.users.where(id: session[:user_id]).first
    end

    # Returns the stored JWT token for the current web session
    def session_token
      session[:jwt_token]
    end

    def logged_in? = !current_web_user.nil?

    def require_login!
      redirect '/login' unless logged_in?
    end

    def require_login_or_401!
      return if logged_in?

      halt 401, JSON.generate({ status: 'error', message: 'Authentication required' })
    end

    def require_level!(level)
      redirect '/login' unless logged_in?
      user = current_web_user
      return if user[:auth_level] >= level

      @error = "Auth Level #{level} required. Your level: L#{user[:auth_level]}."
      halt 403, erb(:error)
    end

    def blurple_theme = LaunchCore::Config::THEME
    def products      = LaunchCore::Config::PRODUCTS
    def auth_levels   = LaunchCore::Config::AUTH_LEVELS

    def product_icon(key)
      icons = {
        voice: '📡', tunnel: '🔒', portal: '🏛', meetings: '🎥',
        workforce: '👥', scheduler: '⏱', neobank: '🏦', brinkspay: '💳',
        tradeshield: '🛡', stophold: '✈', arbiter: '🤖'
      }
      icons[key] || '⬡'
    end

    def auth_level_desc(level)
      descs = {
        1 => 'Password verified. Basic platform access.',
        2 => '2FA enabled. Unlocks portal, scheduling, and AI features.',
        3 => 'KYC complete. Full neobanking, BNPL, and credit access.',
        4 => '30-day active account. JIT travel funding and premium features.'
      }
      descs[level] || ''
    end
  end
  # rubocop:enable Metrics/BlockLength
  before do
    @current_user = current_web_user
    @flash        = session.delete(:flash)
  end

  # ─── Routes: Public ───────────────────────────────────────────────────

  get '/' do
    if logged_in?
      redirect '/dashboard'
    else
      erb :index
    end
  end

  get '/login' do
    redirect '/dashboard' if logged_in?
    @error = nil
    erb :login
  end

  post '/login' do
    email    = params[:email].to_s.strip
    password = params[:password].to_s

    begin
      user  = LaunchCore::Auth::Authenticator.login!(email: email, password: password)
      ents  = begin
        JSON.parse(user[:entitlements] || '{}')
      rescue StandardError
        {}
      end

      token, = LaunchCore::Auth::JWTManager.encode(
        user_id: user[:id],
        email: user[:email],
        user_class: user[:user_class],
        auth_level: user[:auth_level],
        entitlements: ents
      )
      session[:user_id]    = user[:id]
      session[:user_email] = user[:email]
      session[:jwt_token]  = token
      session[:flash]      = "Welcome back, #{user[:first_name]}!"
      redirect '/dashboard'
    rescue LaunchCore::Auth::AuthError => e
      @error = e.message
      erb :login
    end
  end

  get '/signup' do
    redirect '/dashboard' if logged_in?
    @error = nil
    erb :signup
  end

  # rubocop:disable Metrics/BlockLength
  post '/signup' do
    email       = params[:email].to_s.strip
    first_name  = params[:first_name].to_s.strip
    last_name   = params[:last_name].to_s.strip
    phone       = params[:phone].to_s.strip
    invite_code = params[:invite_code].to_s.strip
    password    = params[:password].to_s
    confirm     = params[:password_confirm].to_s

    if password != confirm
      @error = 'Passwords do not match.'
      return erb :signup
    end

    begin
      user = LaunchCore::Auth::Authenticator.signup!(
        email: email,
        password: password,
        first_name: first_name,
        last_name: last_name,
        phone: phone.empty? ? nil : phone,
        invite_code: invite_code.empty? ? nil : invite_code
      )
      session[:user_id]    = user[:id]
      session[:user_email] = user[:email]
      session[:flash]      = "Welcome to LaunchCore, #{user[:first_name]}!"
      redirect '/dashboard'
    rescue LaunchCore::Auth::AuthError => e
      @error = e.message
      erb :signup
    end
  end
  # rubocop:enable Metrics/BlockLength

  get '/logout' do
    if session[:jwt_token]
      begin
        claims, = LaunchCore::Auth::JWTManager.decode(session[:jwt_token])
        LaunchCore::Auth::JWTManager.revoke!(claims['jti']) if claims
      rescue StandardError
        nil
      end
    end
    session.clear
    redirect '/'
  end

  # ─── Routes: Dashboard ────────────────────────────────────────────────

  get '/dashboard' do
    require_login!
    @user    = current_web_user
    @status  = lc_exec('/status')
    erb :dashboard
  end

  # ─── Routes: API / CLI Bridge ─────────────────────────────────────────
  # POST /api/exec  — executes lc [command] --json on behalf of logged-in user
  # Body: { "command": "/voice --sub=status" }

  post '/api/exec' do
    content_type :json
    require_login_or_401!

    data    = JSON.parse(request.body.read, symbolize_names: true)
    command = data[:command].to_s.strip

    # Security: whitelist allowed command prefixes
    allowed_prefixes = %w[/status /help /voice /tunnel /portal /meetings /workforce
                          /scheduler /neobank /brinkspay /tradeshield /stophold /arbiter
                          /auth/invite /settings/2fa /settings/kyc /settings/profile]

    unless allowed_prefixes.any? { |p| command.start_with?(p) }
      env['sinatra.api_error'] = 'Command not allowed via web interface.'
      halt 403
    end

    tmp_session = write_temp_session!
    result = lc_exec(command, extra_env: { 'HOME' => File.dirname(tmp_session) })
    cleanup_temp_session!(tmp_session)

    JSON.generate(result)
  rescue JSON::ParseError
    halt 400, JSON.generate({ status: 'error', message: 'Invalid JSON body' })
  end

  # GET /api/status — quick health check
  get '/api/status' do
    content_type :json
    JSON.generate({
                    status: 'ok',
                    version: LaunchCore::VERSION,
                    time: Time.now.utc.iso8601,
                    authenticated: logged_in?
                  })
  end

  # GET /api/public_key — exposes RS256 public key for Spokes to verify JWTs
  get '/api/public_key' do
    content_type :json
    begin
      pub_key = LaunchCore::Auth::JWTManager.public_key.to_pem
      JSON.generate({ status: 'ok', public_key: pub_key })
    rescue StandardError => e
      status 500
      JSON.generate({ status: 'error', message: e.message })
    end
  end

  # ─── Error pages ──────────────────────────────────────────────────────

  not_found do
    if request.path_info.start_with?('/api/')
      content_type :json
      JSON.generate({ status: 'error', message: 'Not found' })
    else
      @code    = 404
      @message = 'Page not found'
      erb :error
    end
  end

  error 403 do
    if request.path_info.start_with?('/api/')
      content_type :json
      msg = env['sinatra.api_error'] || env['sinatra.error']&.message || 'Access denied'
      JSON.generate({ status: 'error', message: msg })
    else
      @code    = 403
      @message = 'Access denied'
      erb :error
    end
  end

  error 500 do
    if request.path_info.start_with?('/api/')
      content_type :json
      JSON.generate({ status: 'error', message: 'Internal server error' })
    else
      @code    = 500
      @message = 'Internal server error'
      erb :error
    end
  end

  private

  def write_temp_session!
    tmp_dir  = Dir.mktmpdir('lcl-web-')
    tmp_file = File.join(tmp_dir, '.lcl_session')
    File.write(tmp_file, session_token.to_s)
    File.chmod(0o600, tmp_file)
    tmp_file
  end

  def cleanup_temp_session!(tmp_file)
    FileUtils.rm_rf(File.dirname(tmp_file))
  rescue StandardError
    nil
  end
end
