# frozen_string_literal: true

module LaunchCore
  module Config
    # Absolute root — override via LCL_ROOT env var for non-standard deployments
    LCL_ROOT = ENV.fetch('LCL_ROOT', '/home/gary/public_html/lclcli').freeze

    # Single source of truth: all components point here
    DB_PATH = File.join(LCL_ROOT, 'data', 'launchcore.db').freeze

    # Local user paths
    SESSION_FILE  = File.expand_path('~/.lcl_session').freeze
    HISTORY_FILE  = File.expand_path('~/.lcl_history').freeze
    KEYS_DIR      = File.expand_path('~/.lcl_keys').freeze
    PRIVATE_KEY   = File.join(KEYS_DIR, 'private.pem').freeze
    PUBLIC_KEY    = File.join(KEYS_DIR, 'public.pem').freeze

    # Email
    SENDER_EMAIL  = 'noreply@launchcloudlabs.com'
    COMPANY_NAME  = 'LaunchCloud Labs'
    DOMAIN        = 'launchcloudlabs.com'

    # Midnight Blurple palette (terminal ANSI + hex)
    THEME = {
      success: { ansi: "\e[38;2;0;255;65m",    hex: '#00FF41' },  # Matrix green
      warning: { ansi: "\e[38;2;255;191;0m",   hex: '#FFBF00' },  # Amber
      critical: { ansi: "\e[38;2;255;49;49m", hex: '#FF3131' }, # Red alert
      primary: { ansi: "\e[38;2;88;101;242m", hex: '#5865F2' }, # Blurple
      accent: { ansi: "\e[38;2;0;212;255m", hex: '#00D4FF' }, # Cyan
      muted: { ansi: "\e[38;2;100;100;120m", hex: '#646478' }, # Muted
      bold: "\e[1m",
      reset: "\e[0m",
      dim: "\e[2m",
      underline: "\e[4m"
    }.freeze

    # JWT configuration
    JWT_ALGORITHM  = 'RS256'
    JWT_EXPIRY     = 86_400 # 24 hours in seconds
    JWT_ISSUER     = 'launchcore-cli'
    JWT_AUDIENCE   = 'lcl-platform'

    # Auth level thresholds
    AUTH_LEVELS = {
      1 => 'Password Verified',
      2 => 'Email / 2FA Verified',
      3 => 'KYC / ID Verified (NeoBank Ready)',
      4 => '30-Day Active + L1-L3 Fulfilled'
    }.freeze

    # User classes
    USER_CLASSES = {
      'power_user' => 'Power User (Solo)',
      'company' => 'Company (Org Admin)',
      'company_agent' => 'Company Agent (Employee)'
    }.freeze

    # 11-Product stack — entitlement key, display name, min class, min auth_level
    PRODUCTS = {
      voice: { name: 'Command-Voice', tech: 'VoIP / Telnyx / Asterisk', min_class: :any,
               min_level: 1 },
      tunnel: { name: 'Command-Tunnel',        tech: 'Obfuscated VPN / AmneziaWG',       min_class: :any,
                min_level: 1 },
      portal: { name: 'Command-Portal',        tech: 'Operations Hub',                   min_class: :any,
                min_level: 2 },
      meetings: { name: 'Neural Meetings', tech: 'Encrypted Jitsi', min_class: :any,
                  min_level: 1 },
      workforce: { name: 'Workforce Module',      tech: 'Recruitment Engine',               min_class: :company,
                   min_level: 2 },
      scheduler: { name: 'The Scheduler',         tech: 'Credential Kill-Switch',           min_class: :any,
      timeclock: { name: 'Command-TimeClock', min_level: 1, tech: 'SQLite / Time-Tracking' },
                   min_level: 2 },
      neobank: { name: 'Neobank + DWR', tech: 'Programmable Banking / Mercury / Lithic', min_class: :any,
                 min_level: 3 },
      brinkspay: { name: 'BrinksPay',             tech: 'BNPL / Credit / Bloom',            min_class: :any,
                   min_level: 3 },
      tradeshield: { name: 'TradeShield',         tech: 'Credit Reporting / CRS / Metro 2', min_class: :any,
                     min_level: 3 },
      stophold: { name: 'Stophold', tech: 'JIT Travel Funding', min_class: :any,
                  min_level: 4 },
      arbiter: { name: 'Arbiter AI', tech: 'Gemini / Claude / xAI Router', min_class: :any,
                 min_level: 2 }
    }.freeze

    HISTORY_LIMIT = 500
    MAX_LOGIN_ATTEMPTS = 5
    LOCKOUT_DURATION   = 900 # 15 minutes in seconds

    def self.ensure_local_dirs!
      [KEYS_DIR, File.dirname(SESSION_FILE)].each do |dir|
        FileUtils.mkdir_p(dir)
        FileUtils.chmod(0o700, dir) if File.directory?(dir)
      rescue Errno::EEXIST
        # Directory already exists — OK
      end
    end

    def self.ensure_db_dir!
      FileUtils.mkdir_p(File.dirname(DB_PATH))
    end
  end
end
