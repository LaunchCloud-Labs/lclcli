# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LaunchCore::Mailer do
  before { Mail::TestMailer.deliveries.clear }

  shared_examples 'a delivered email' do |to_field|
    it 'delivers to the correct address' do
      delivery = Mail::TestMailer.deliveries.last
      expect(delivery).not_to be_nil
      expected = to_field.is_a?(Proc) ? to_field.call : to_field
      expect(Array(delivery.to)).to include(expected)
    end

    it 'sets the from field to noreply@launchcloudlabs.com' do
      delivery = Mail::TestMailer.deliveries.last
      expect(delivery.from.to_s).to include('launchcloudlabs.com')
    end
  end

  describe '.welcome' do
    before { described_class.welcome(email: 'user@example.com', first_name: 'Jane') }

    include_examples 'a delivered email', 'user@example.com'

    it 'includes the first name in the subject' do
      delivery = Mail::TestMailer.deliveries.last
      expect(delivery.subject).to match(/Jane/)
    end

    it 'includes NEXT STEPS in the body' do
      delivery = Mail::TestMailer.deliveries.last
      expect(delivery.body.to_s).to include('NEXT STEPS')
    end
  end

  describe '.invite' do
    before { described_class.invite(to: 'new@example.com', code: 'INV-1234', role: 'power_user') }

    include_examples 'a delivered email', 'new@example.com'

    it 'includes the invite code in the body' do
      delivery = Mail::TestMailer.deliveries.last
      expect(delivery.body.to_s).to include('INV-1234')
    end

    it 'skips delivery when to: is nil' do
      Mail::TestMailer.deliveries.clear
      described_class.invite(to: nil, code: 'X', role: 'power_user')
      expect(Mail::TestMailer.deliveries).to be_empty
    end
  end

  describe '.auth_level_upgrade' do
    before do
      described_class.auth_level_upgrade(
        email: 'user@example.com', first_name: 'Bob', new_level: 2
      )
    end

    include_examples 'a delivered email', 'user@example.com'

    it 'mentions the new level in the subject' do
      delivery = Mail::TestMailer.deliveries.last
      expect(delivery.subject).to include('L2')
    end

    it 'includes the level description in the body' do
      delivery = Mail::TestMailer.deliveries.last
      expect(delivery.body.to_s).to include('Auth Level 2')
    end
  end
end
