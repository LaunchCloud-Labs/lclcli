# frozen_string_literal: true

require 'sequel'
require 'sqlite3'

module LaunchCore
  # rubocop:disable Metrics/ModuleLength
  module Database
    class << self
      def connection
        @connection ||= connect!
      end
      alias db connection

      def connect!
        Config.ensure_db_dir!
        db_path = ENV.fetch('LCL_DB_PATH', Config::DB_PATH)
        conn = Sequel.connect("sqlite://#{db_path}", loggers: [])
        conn.run('PRAGMA foreign_keys = ON')
        conn.run('PRAGMA journal_mode = WAL')
        conn.run('PRAGMA synchronous = NORMAL')
        apply_schema!(conn)
        conn
      end

      def disconnect!
        @connection&.disconnect
        @connection = nil
      end

      def migrate!
        apply_schema!(connection)
      end

      private

      # rubocop:disable Metrics/MethodLength
      def apply_schema!(conn)
        conn.run(<<~SQL)
          CREATE TABLE IF NOT EXISTS companies (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            name        TEXT    NOT NULL,
            slug        TEXT    UNIQUE NOT NULL,
            owner_id    INTEGER,
            auth_level  INTEGER NOT NULL DEFAULT 1,
            status      TEXT    NOT NULL DEFAULT 'active',
            entitlements TEXT   NOT NULL DEFAULT '{}',
            created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
          );
        SQL

        conn.run(<<~SQL)
          CREATE TABLE IF NOT EXISTS users (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            email           TEXT    UNIQUE NOT NULL COLLATE NOCASE,
            password_digest TEXT    NOT NULL,
            first_name      TEXT,
            last_name       TEXT,
            phone           TEXT,
            user_class      TEXT    NOT NULL DEFAULT 'power_user',
            auth_level      INTEGER NOT NULL DEFAULT 1,
            status          TEXT    NOT NULL DEFAULT 'pending',
            kyc_verified    INTEGER NOT NULL DEFAULT 0,
            totp_secret     TEXT,
            totp_enabled    INTEGER NOT NULL DEFAULT 0,
            entitlements    TEXT    NOT NULL DEFAULT '{}',
            invite_code     TEXT,
            invited_by      INTEGER REFERENCES users(id) ON DELETE SET NULL,
            company_id      INTEGER REFERENCES companies(id) ON DELETE SET NULL,
            failed_logins   INTEGER NOT NULL DEFAULT 0,
            locked_until    DATETIME,
            created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            last_login_at   DATETIME,
            account_active_days INTEGER NOT NULL DEFAULT 0
          );
        SQL

        conn.run(<<~SQL)
          CREATE TABLE IF NOT EXISTS sessions (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            jti         TEXT    UNIQUE NOT NULL,
            user_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            expires_at  DATETIME NOT NULL,
            revoked     INTEGER NOT NULL DEFAULT 0,
            revoked_at  DATETIME,
            ip_address  TEXT,
            user_agent  TEXT
          );
        SQL

        conn.run(<<~SQL)
          CREATE TABLE IF NOT EXISTS invites (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            code          TEXT    UNIQUE NOT NULL,
            inviter_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            used_by       INTEGER REFERENCES users(id) ON DELETE SET NULL,
            invitee_email TEXT,
            role          TEXT    NOT NULL DEFAULT 'company_agent',
            company_id    INTEGER REFERENCES companies(id) ON DELETE SET NULL,
            used_at       DATETIME,
            expires_at    DATETIME NOT NULL,
            redeemed      INTEGER NOT NULL DEFAULT 0,
            revoked       INTEGER NOT NULL DEFAULT 0,
            created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
          );
        SQL

        conn.run(<<~SQL)
          CREATE TABLE IF NOT EXISTS audit_log (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id     INTEGER REFERENCES users(id) ON DELETE SET NULL,
            action      TEXT    NOT NULL,
            detail      TEXT,
            ip          TEXT,
            status      TEXT    NOT NULL DEFAULT 'success',
            metadata    TEXT    NOT NULL DEFAULT '{}',
            created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
          );
        SQL

        conn.run(<<~SQL)
          CREATE TABLE IF NOT EXISTS kyc_submissions (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            status      TEXT    NOT NULL DEFAULT 'pending',
            document_type TEXT,
            submitted_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            reviewed_at   DATETIME,
            reviewer_note TEXT
          );
        SQL

        # Indexes
        conn.run('CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);')
        conn.run('CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions (user_id);')
        conn.run('CREATE INDEX IF NOT EXISTS idx_sessions_jti ON sessions (jti);')
        conn.run('CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_log (user_id);')
        conn.run('CREATE INDEX IF NOT EXISTS idx_invites_code ON invites (code);')
      end
      # rubocop:enable Metrics/MethodLength
    end

    # --------------- Model helpers ---------------

    module Models
      def self.users      = Database.db[:users]
      def self.companies  = Database.db[:companies]
      def self.sessions   = Database.db[:sessions]
      def self.invites    = Database.db[:invites]
      def self.audit_log  = Database.db[:audit_log]
      def self.kyc        = Database.db[:kyc_submissions]

      # rubocop:disable Metrics/ParameterLists
      def self.log(user_id:, action:, resource: nil, status: 'success', metadata: {}, ip: nil)
        audit_log.insert(
          user_id: user_id,
          action: action,
          detail: resource,
          status: status,
          ip: ip,
          metadata: JSON.generate(metadata),
          created_at: Time.now.utc.iso8601
        )
      end
      # rubocop:enable Metrics/ParameterLists
    end
  end
  # rubocop:enable Metrics/ModuleLength
end
