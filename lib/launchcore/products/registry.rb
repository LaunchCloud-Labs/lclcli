# frozen_string_literal: true

module LaunchCore
  module Products
    # Central registry — lazy-loads product instances
    class Registry
      PRODUCT_CLASSES = {
        voice: 'LaunchCore::Products::Voice',
        tunnel: 'LaunchCore::Products::Tunnel',
        portal: 'LaunchCore::Products::Portal',
        meetings: 'LaunchCore::Products::NeuralMeetings',
        workforce: 'LaunchCore::Products::Workforce',
        scheduler: 'LaunchCore::Products::Scheduler',
        neobank: 'LaunchCore::Products::Neobank',
        brinkspay: 'LaunchCore::Products::BrinksPay',
        tradeshield: 'LaunchCore::Products::TradeShield',
        stophold: 'LaunchCore::Products::Stophold',
        arbiter: 'LaunchCore::Products::Arbiter'
      }.freeze

      class << self
        def fetch(key)
          @instances ||= {}
          @instances[key] ||= begin
            klass_name = PRODUCT_CLASSES[key] || raise(ArgumentError, "No class for product: #{key}")
            Object.const_get(klass_name).new(key)
          end
        end

        def all_keys = PRODUCT_CLASSES.keys
      end
    end
  end
end
