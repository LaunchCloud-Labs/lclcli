# frozen_string_literal: true

module LaunchCore
  module Products
    # Base class for all 11 LaunchCore products
    class Base
      attr_reader :key, :config

      def initialize(key)
        @key    = key
        @config = Config::PRODUCTS[key] || raise(ArgumentError, "Unknown product: #{key}")
      end

      # Override in subclasses — args is a parsed hash, session is Auth::Session
      def execute(args, session:)
        raise NotImplementedError, "#{self.class}#execute not implemented"
      end

      protected

      def json_ok(data = {}, message: nil)
        Output.json_response(
          status: 'ok',
          message: message || "#{@config[:name]} — ready",
          command: "/#{@key}",
          data: data
        )
      end

      def json_error(message)
        Output.json_response(status: 'error', message: message, command: "/#{@key}")
      end

      def unavailable_notice
        if Output.json_mode
          json_ok(
            { available: false, coming_soon: true },
            message: "#{@config[:name]} — Module available in full release"
          )
        else
          Output.blank
          Output.header(@config[:name])
          Output.blank
          Output.info("Technology: #{@config[:tech]}")
          Output.blank
          Output.warning('This product is available in the LaunchCore full release.')
          Output.muted("Visit https://#{Config::DOMAIN} to join the waitlist.")
          Output.blank
        end
      end

      def render_header(title = nil)
        return if Output.json_mode

        Output.blank
        Output.header(title || @config[:name])
        Output.blank
        Output.muted("Technology: #{@config[:tech]}")
        Output.blank
      end
    end
  end
end
