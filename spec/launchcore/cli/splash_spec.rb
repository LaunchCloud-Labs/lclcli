# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LaunchCore::CLI::Splash do
  let(:stdout_capture) { StringIO.new }

  before do
    @orig_stdout = $stdout
    $stdout = stdout_capture
  end

  after do
    $stdout = @orig_stdout
  end

  describe '.render' do
    it 'prints the splash screen without raising' do
      expect { described_class.render }.not_to raise_error
    end

    it 'prints something to stdout' do
      described_class.render
      expect(stdout_capture.string).not_to be_empty
    end

    it 'includes LaunchCore branding' do
      described_class.render
      expect(stdout_capture.string).to match(/launch(core|cloud)/i)
    end
  end

  describe '.render (compact: true)' do
    it 'prints compact splash without raising' do
      expect { described_class.render(compact: true) }.not_to raise_error
    end

    it 'prints something to stdout in compact mode' do
      described_class.render(compact: true)
      expect(stdout_capture.string).not_to be_empty
    end
  end

  describe '.render_json' do
    it 'returns a hash with product and version' do
      result = described_class.render_json
      expect(result[:product]).to  be_a(String)
      expect(result[:version]).to  eq(LaunchCore::VERSION)
      expect(result[:domain]).to   include('launchcloudlabs.com')
      expect(result[:codename]).to eq(LaunchCore::CODENAME)
    end
  end

  describe 'LOGO and BANNER_COMPACT constants' do
    it 'LOGO is a non-empty string' do
      expect(described_class::LOGO).to be_a(String)
      expect(described_class::LOGO).not_to be_empty
    end

    it 'BANNER_COMPACT is a non-empty string' do
      expect(described_class::BANNER_COMPACT).to be_a(String)
      expect(described_class::BANNER_COMPACT).not_to be_empty
    end
  end
end
