# frozen_string_literal: true

module DatabaseHelper
  def truncate_tables!
    db = LaunchCore::Database.connection
    %i[audit_log kyc_submissions invites sessions users companies].each do |table|
      db[table].delete
    end
  end

  def create_test_user(overrides = {})
    attrs = {
      email:          "test_#{SecureRandom.hex(4)}@example.com",
      password:       'TestPass1!abcd',
      first_name:     'Test',
      last_name:      'User',
      phone:          nil,
      invite_code:    nil
    }.merge(overrides)

    result = LaunchCore::Auth::Authenticator.signup(
      email:       attrs[:email],
      password:    attrs[:password],
      first_name:  attrs[:first_name],
      last_name:   attrs[:last_name],
      phone:       attrs[:phone],
      invite_code: attrs[:invite_code]
    )
    raise "create_test_user failed: #{result[:message]}" unless result[:status] == 'ok'

    db = LaunchCore::Database.connection
    user = db[:users].where(email: attrs[:email]).first
    raise 'User not found after signup' unless user

    user
  end

  def create_test_company
    db = LaunchCore::Database.connection
    id = db[:companies].insert(
      name:       "Test Corp #{SecureRandom.hex(4)}",
      created_at: Time.now.utc.iso8601
    )
    db[:companies].where(id: id).first
  end

  def login_user(email:, password:)
    LaunchCore::Auth::Authenticator.login(email: email, password: password)
  end
end
