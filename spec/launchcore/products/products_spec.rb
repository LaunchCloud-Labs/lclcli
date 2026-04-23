# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'LaunchCore Products' do
  include DatabaseHelper

  before(:each) do
    truncate_tables!
    LaunchCore::Output.silent_mode = true
    LaunchCore::Output.json_mode   = true
  end

  after(:each) do
    LaunchCore::Output.silent_mode = false
    LaunchCore::Output.json_mode   = false
  end

  let(:user)    { create_test_user }
  let(:session) do
    s = LaunchCore::Auth::Session.new
    token, = LaunchCore::Auth::JWTManager.encode(
      user_id:    user[:id],
      email:      user[:email],
      user_class: user[:user_class],
      auth_level: 4
    )
    s.store!(token)
    s
  end

  # ─── Registry ────────────────────────────────────────────────────────────────

  describe LaunchCore::Products::Registry do
    describe '.all_keys' do
      it 'returns all 11 product keys' do
        keys = described_class.all_keys
        expect(keys.length).to eq(11)
        expect(keys).to include(:voice, :tunnel, :portal, :meetings, :workforce,
                                :scheduler, :neobank, :brinkspay, :tradeshield,
                                :stophold, :arbiter)
      end
    end

    describe '.fetch' do
      it 'returns a product instance for each registered key' do
        described_class.all_keys.each do |key|
          product = described_class.fetch(key)
          expect(product).to be_a(LaunchCore::Products::Base)
          expect(product.key).to eq(key)
        end
      end

      it 'returns the same instance on repeated calls (memoized)' do
        p1 = described_class.fetch(:voice)
        p2 = described_class.fetch(:voice)
        expect(p1).to equal(p2)
      end

      it 'raises ArgumentError for unknown product keys' do
        expect { described_class.fetch(:unicorn) }
          .to raise_error(ArgumentError, /No class for product/)
      end
    end
  end

  # ─── Base class ──────────────────────────────────────────────────────────────

  describe LaunchCore::Products::Base do
    it 'raises NotImplementedError on execute' do
      expect { described_class.new(:voice).execute({}, session: session) }
        .to raise_error(NotImplementedError)
    end

    it 'raises ArgumentError for unknown product key' do
      expect { described_class.new(:unknown_xyz) }
        .to raise_error(ArgumentError, /Unknown product/)
    end

    let(:product) { LaunchCore::Products::Portal.new(:portal) }

    describe '#json_error' do
      it 'returns an error hash with the given message' do
        result = product.send(:json_error, 'Test failure message')
        expect(result[:status]).to eq('error')
        expect(result[:message]).to eq('Test failure message')
      end
    end

    describe '#unavailable_notice' do
      it 'returns a json hash with available=false in json_mode' do
        result = product.send(:unavailable_notice)
        expect(result[:data][:available]).to be false
        expect(result[:data][:coming_soon]).to be true
      end

      it 'renders text output in non-json mode without raising' do
        LaunchCore::Output.json_mode = false
        begin
          expect { product.send(:unavailable_notice) }.not_to raise_error
        ensure
          LaunchCore::Output.json_mode = true
        end
      end
    end
  end

  # ─── Individual products (smoke-test execute) ─────────────────────────────────

  {
    voice:       LaunchCore::Products::Voice,
    tunnel:      LaunchCore::Products::Tunnel,
    portal:      LaunchCore::Products::Portal,
    meetings:    LaunchCore::Products::NeuralMeetings,
    workforce:   LaunchCore::Products::Workforce,
    scheduler:   LaunchCore::Products::Scheduler,
    neobank:     LaunchCore::Products::Neobank,
    brinkspay:   LaunchCore::Products::BrinksPay,
    tradeshield: LaunchCore::Products::TradeShield,
    stophold:    LaunchCore::Products::Stophold,
    arbiter:     LaunchCore::Products::Arbiter
  }.each do |key, klass|
    describe klass do
      let(:product) { klass.new(key) }

      it 'initialises without error' do
        expect { product }.not_to raise_error
      end

      it 'has a config with name and min_level' do
        expect(product.config[:name]).to be_a(String)
        expect(product.config[:min_level]).to be_between(1, 4)
      end

      it 'executes with default args and returns a hash-like result (json mode)' do
        result = product.execute({}, session: session)
        expect(result).to be_a(Hash)
        expect(result[:status]).to be_a(String)
      end
    end
  end

  # ─── Subcommand coverage ─────────────────────────────────────────────────────

  describe LaunchCore::Products::Voice do
    let(:product) { described_class.new(:voice) }

    it 'handles status sub' do
      result = product.execute({ sub: 'status' }, session: session)
      expect(result[:status]).to eq('ok')
    end

    it 'handles numbers sub' do
      result = product.execute({ sub: 'numbers' }, session: session)
      expect(result[:status]).to eq('ok')
    end

    it 'handles call sub (missing args → ok or error, not crash)' do
      result = product.execute({ sub: 'call', to: '+15555555555', from: '+15550000000' }, session: session)
      expect(result).to be_a(Hash)
    end

    it 'handles sms sub' do
      result = product.execute({ sub: 'sms', to: '+15555555555', message: 'hi' }, session: session)
      expect(result).to be_a(Hash)
    end
  end

  describe LaunchCore::Products::Tunnel do
    let(:product) { described_class.new(:tunnel) }

    it 'handles status sub' do
      result = product.execute({ sub: 'status' }, session: session)
      expect(result[:status]).to eq('ok')
    end

    it 'handles connect sub' do
      result = product.execute({ sub: 'connect' }, session: session)
      expect(result).to be_a(Hash)
    end
  end

  describe LaunchCore::Products::Neobank do
    let(:product) { described_class.new(:neobank) }

    it 'handles balance sub' do
      result = product.execute({ sub: 'balance' }, session: session)
      expect(result[:status]).to eq('ok')
    end

    it 'handles cards sub' do
      result = product.execute({ sub: 'cards' }, session: session)
      expect(result[:status]).to eq('ok')
    end

    it 'handles payroll sub' do
      result = product.execute({ sub: 'payroll' }, session: session)
      expect(result).to be_a(Hash)
    end
  end

  describe LaunchCore::Products::Stophold do
    let(:product) { described_class.new(:stophold) }

    it 'handles history sub' do
      result = product.execute({ sub: 'history' }, session: session)
      expect(result[:status]).to eq('ok')
    end

    it 'handles status sub' do
      result = product.execute({ sub: 'status' }, session: session)
      expect(result).to be_a(Hash)
    end
  end

  describe LaunchCore::Products::Arbiter do
    let(:product) { described_class.new(:arbiter) }

    it 'handles query sub' do
      result = product.execute({ sub: 'query', prompt: 'hello' }, session: session)
      expect(result).to be_a(Hash)
    end

    it 'handles models sub' do
      result = product.execute({ sub: 'models' }, session: session)
      expect(result).to be_a(Hash)
    end
  end

  describe LaunchCore::Products::Portal do
    let(:product) { described_class.new(:portal) }

    it 'handles users sub' do
      result = product.execute({ sub: 'users' }, session: session)
      expect(result).to be_a(Hash)
    end
  end

  describe LaunchCore::Products::Workforce do
    let(:product) { described_class.new(:workforce) }

    it 'handles list sub' do
      result = product.execute({ sub: 'list' }, session: session)
      expect(result).to be_a(Hash)
    end
  end

  describe LaunchCore::Products::Scheduler do
    let(:product) { described_class.new(:scheduler) }

    it 'handles status sub' do
      result = product.execute({ sub: 'status' }, session: session)
      expect(result).to be_a(Hash)
    end
  end

  describe LaunchCore::Products::BrinksPay do
    let(:product) { described_class.new(:brinkspay) }

    it 'handles status sub' do
      result = product.execute({ sub: 'status' }, session: session)
      expect(result).to be_a(Hash)
    end
  end

  describe LaunchCore::Products::TradeShield do
    let(:product) { described_class.new(:tradeshield) }

    it 'handles report sub' do
      result = product.execute({ sub: 'report' }, session: session)
      expect(result).to be_a(Hash)
    end
  end

  describe LaunchCore::Products::NeuralMeetings do
    let(:product) { described_class.new(:meetings) }

    it 'handles start sub' do
      result = product.execute({ sub: 'start' }, session: session)
      expect(result).to be_a(Hash)
    end
  end
end
