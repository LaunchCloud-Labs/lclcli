# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LaunchCore::Config do
  describe 'LCL_ROOT' do
    it 'is an absolute path string' do
      expect(described_class::LCL_ROOT).to be_a(String)
      expect(described_class::LCL_ROOT).to start_with('/')
    end
  end

  describe 'JWT constants' do
    it 'uses RS256 algorithm' do
      expect(described_class::JWT_ALGORITHM).to eq('RS256')
    end

    it 'defines a non-empty issuer' do
      expect(described_class::JWT_ISSUER).not_to be_empty
    end

    it 'defines a non-empty audience' do
      expect(described_class::JWT_AUDIENCE).not_to be_empty
    end

    it 'defines a positive expiry' do
      expect(described_class::JWT_EXPIRY).to be > 0
    end
  end

  describe 'AUTH_LEVELS' do
    it 'defines four levels 1-4' do
      expect(described_class::AUTH_LEVELS.keys).to contain_exactly(1, 2, 3, 4)
    end

    it 'has string labels for each level' do
      described_class::AUTH_LEVELS.each_value do |label|
        expect(label).to be_a(String)
        expect(label).not_to be_empty
      end
    end
  end

  describe 'USER_CLASSES' do
    it 'defines at least power_user and company classes' do
      expect(described_class::USER_CLASSES).to include('power_user', 'company')
    end
  end

  describe 'PRODUCTS' do
    it 'defines all 11 products' do
      expect(described_class::PRODUCTS.keys.length).to eq(11)
    end

    it 'each product has name, tech, and min_level' do
      described_class::PRODUCTS.each_value do |attrs|
        expect(attrs).to include(:name, :tech, :min_level)
      end
    end

    it 'min_level is between 1 and 4 for all products' do
      described_class::PRODUCTS.each_value do |attrs|
        expect(attrs[:min_level]).to be_between(1, 4)
      end
    end
  end

  describe 'THEME' do
    it 'defines success, warning, and critical keys' do
      expect(described_class::THEME).to include(:success, :warning, :critical)
    end
  end

  describe 'email config' do
    it 'defines SENDER_EMAIL ending in launchcloudlabs.com' do
      expect(described_class::SENDER_EMAIL).to include('launchcloudlabs.com')
    end
  end
end
