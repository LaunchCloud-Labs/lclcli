-- LaunchCore Command — SQLite Schema
-- LaunchCloud Labs © 2026
-- Single source of truth: LCL_ROOT/data/launchcore.db
-- ===========================================================

PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;
PRAGMA synchronous  = NORMAL;

-- ── Companies ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS companies (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  name       TEXT    NOT NULL,
  created_at TEXT    NOT NULL DEFAULT (datetime('now'))
);

-- ── Users ───────────────────────────────────────────────────
-- auth_level  : 1=password, 2=2FA, 3=KYC, 4=30-day active
-- user_class  : power_user | company | company_agent
-- entitlements: JSON object of granted product flags
CREATE TABLE IF NOT EXISTS users (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  company_id      INTEGER REFERENCES companies(id) ON DELETE SET NULL,
  email           TEXT    NOT NULL UNIQUE COLLATE NOCASE,
  password_digest TEXT    NOT NULL,
  first_name      TEXT,
  last_name       TEXT,
  phone           TEXT,
  user_class      TEXT    NOT NULL DEFAULT 'power_user'
                          CHECK (user_class IN ('power_user','company','company_agent')),
  auth_level      INTEGER NOT NULL DEFAULT 1
                          CHECK (auth_level BETWEEN 1 AND 4),
  status          TEXT    NOT NULL DEFAULT 'active'
                          CHECK (status IN ('active','suspended','pending')),
  totp_secret     TEXT,
  totp_enabled    INTEGER NOT NULL DEFAULT 0,
  kyc_verified    INTEGER NOT NULL DEFAULT 0,
  entitlements    TEXT    NOT NULL DEFAULT '{}',
  failed_logins   INTEGER NOT NULL DEFAULT 0,
  locked_until    TEXT,
  last_login_at   TEXT,
  created_at      TEXT    NOT NULL DEFAULT (datetime('now')),
  updated_at      TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_users_email      ON users (email);
CREATE INDEX IF NOT EXISTS idx_users_auth_level ON users (auth_level);
CREATE INDEX IF NOT EXISTS idx_users_company    ON users (company_id);

-- ── Sessions (JWT revocation registry) ──────────────────────
CREATE TABLE IF NOT EXISTS sessions (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  jti        TEXT    NOT NULL UNIQUE,
  revoked    INTEGER NOT NULL DEFAULT 0,
  created_at TEXT    NOT NULL DEFAULT (datetime('now')),
  expires_at TEXT    NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_sessions_jti     ON sessions (jti);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions (user_id);

-- ── Invites ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS invites (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  inviter_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  invitee_email TEXT    NOT NULL,
  code          TEXT    NOT NULL UNIQUE,
  redeemed      INTEGER NOT NULL DEFAULT 0,
  created_at    TEXT    NOT NULL DEFAULT (datetime('now')),
  expires_at    TEXT
);

CREATE INDEX IF NOT EXISTS idx_invites_code ON invites (code);

-- ── Audit Log ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS audit_log (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER REFERENCES users(id) ON DELETE SET NULL,
  action     TEXT NOT NULL,
  detail     TEXT,
  ip         TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_audit_user_id  ON audit_log (user_id);
CREATE INDEX IF NOT EXISTS idx_audit_action   ON audit_log (action);
CREATE INDEX IF NOT EXISTS idx_audit_created  ON audit_log (created_at);

-- ── KYC Submissions ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS kyc_submissions (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id      INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status       TEXT    NOT NULL DEFAULT 'pending'
                       CHECK (status IN ('pending','approved','rejected')),
  provider     TEXT,
  reference_id TEXT,
  submitted_at TEXT    NOT NULL DEFAULT (datetime('now')),
  resolved_at  TEXT
);

CREATE INDEX IF NOT EXISTS idx_kyc_user_id ON kyc_submissions (user_id);
