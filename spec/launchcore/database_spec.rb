# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LaunchCore::Database do
  let(:db) { described_class.connection }

  # ── Connection ───────────────────────────────────────────────
  describe '.connection' do
    it 'returns a Sequel::Database instance' do
      expect(db).to be_a(Sequel::Database)
    end

    it 'returns the same instance on repeated calls (singleton)' do
      expect(described_class.connection).to be(db)
    end
  end

  # ── Schema: users ────────────────────────────────────────────
  describe 'users table' do
    it 'has the required columns' do
      cols = db.schema(:users).map(&:first)
      expect(cols).to include(
        :id, :email, :password_digest, :first_name, :last_name,
        :auth_level, :user_class, :status, :created_at,
        :failed_logins, :locked_until, :entitlements
      )
    end

    it 'enforces unique email constraint' do
      db[:users].insert(
        email:           'dup@example.com',
        password_digest: 'x',
        auth_level:      1,
        user_class:      'power_user',
        status:          'active',
        entitlements:    '{}',
        created_at:      Time.now.utc.iso8601
      )
      expect {
        db[:users].insert(
          email:           'dup@example.com',
          password_digest: 'y',
          auth_level:      1,
          user_class:      'power_user',
          status:          'active',
          entitlements:    '{}',
          created_at:      Time.now.utc.iso8601
        )
      }.to raise_error(Sequel::UniqueConstraintViolation)
    end
  end

  # ── Schema: sessions ─────────────────────────────────────────
  describe 'sessions table' do
    let!(:user) { create_test_user }

    it 'has the required columns' do
      cols = db.schema(:sessions).map(&:first)
      expect(cols).to include(:id, :user_id, :jti, :revoked, :created_at, :expires_at)
    end

    it 'can insert and retrieve a session by JTI' do
      jti = SecureRandom.uuid
      db[:sessions].insert(
        user_id:    user[:id],
        jti:        jti,
        revoked:    0,
        created_at: Time.now.utc.iso8601,
        expires_at: (Time.now + 3600).utc.iso8601
      )
      found = db[:sessions].where(jti: jti).first
      expect(found).not_to be_nil
      expect(found[:revoked]).to eq(0).or eq(false)
    end
  end

  # ── Schema: invites ──────────────────────────────────────────
  describe 'invites table' do
    let!(:user) { create_test_user }

    it 'has the required columns' do
      cols = db.schema(:invites).map(&:first)
      expect(cols).to include(:id, :code, :inviter_id, :invitee_email, :redeemed, :created_at)
    end
  end

  # ── Schema: audit_log ────────────────────────────────────────
  describe 'audit_log table' do
    it 'has the required columns' do
      cols = db.schema(:audit_log).map(&:first)
      expect(cols).to include(:id, :user_id, :action, :detail, :ip, :created_at)
    end
  end

  # ── Schema: companies ────────────────────────────────────────
  describe 'companies table' do
    it 'has the required columns' do
      cols = db.schema(:companies).map(&:first)
      expect(cols).to include(:id, :name, :created_at)
    end
  end

  # ── Schema: kyc_submissions ──────────────────────────────────
  describe 'kyc_submissions table' do
    it 'has the required columns' do
      cols = db.schema(:kyc_submissions).map(&:first)
      expect(cols).to include(:id, :user_id, :status, :submitted_at)
    end
  end

  # ── Models ───────────────────────────────────────────────────
  describe 'Models module' do
    it 'exposes .users dataset' do
      expect(LaunchCore::Database::Models.users).to respond_to(:where)
    end

    it 'exposes .sessions dataset' do
      expect(LaunchCore::Database::Models.sessions).to respond_to(:insert)
    end

    it 'exposes .invites dataset' do
      expect(LaunchCore::Database::Models.invites).to respond_to(:where)
    end
  end
end
