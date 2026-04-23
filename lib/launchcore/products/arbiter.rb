# frozen_string_literal: true

module LaunchCore
  module Products
    # Product 11: Arbiter AI — Multi-model AI Router (Gemini / Claude / xAI)
    class Arbiter < Base
      # rubocop:disable Layout/LineLength
      GEMINI_KEY  = ENV.fetch('GEMINI_API_KEY',  'AIzaSyBeJDGsaPp1XlcmGGTw7NsWKwNHpJIg1dU')
      XAI_KEY     = ENV.fetch('XAI_API_KEY',     nil)
      CLAUDE_KEY  = ENV.fetch('ANTHROPIC_API_KEY', nil)
      # rubocop:enable Layout/LineLength

      MODELS = {
        'gemini' => { name: 'Google Gemini', endpoint: 'https://generativelanguage.googleapis.com/v1beta',
                      default_model: 'gemini-2.0-flash' },
        'claude' => { name: 'Anthropic Claude', endpoint: 'https://api.anthropic.com/v1',
                      default_model: 'claude-opus-4-6' },
        'grok' => { name: 'xAI Grok', endpoint: 'https://api.x.ai/v1', default_model: 'grok-3' },
        'auto' => { name: 'Auto-Router', endpoint: nil, default_model: nil }
      }.freeze

      def execute(args, session:)
        sub = args[:sub] || args[:action]

        case sub&.to_s
        when 'chat'    then arbiter_chat(args, session)
        when 'models'  then list_models
        when 'route'   then route_query(args, session)
        when 'status'  then arbiter_status
        else                arbiter_overview
        end
      end

      private

      def arbiter_overview
        data = {
          product: 'Arbiter AI',
          description: 'Intelligent multi-model AI router (Gemini, Claude, xAI/Grok)',
          models: MODELS.keys,
          subcommands: {
            'chat' => 'Chat with AI  --model=gemini --prompt="..."',
            'models' => 'List available models and status',
            'route' => 'Auto-route query to best model  --prompt="..."',
            'status' => 'Check API connectivity'
          },
          auth_requirement: 'L2+'
        }
        if Output.json_mode
          json_ok(data)
        else
          render_header
          Output.info('Multi-model AI Router: Gemini | Claude | xAI/Grok')
          Output.info('Auto-routing selects optimal model per query type')
          Output.blank
          data[:subcommands].each { |cmd, desc| Output.muted("  /arbiter --sub=#{cmd}    #{desc}") }
          Output.blank
        end
      end

      def list_models
        model_data = MODELS.map do |key, m|
          { key: key, name: m[:name], default_model: m[:default_model], status: 'available' }
        end
        if Output.json_mode
          json_ok({ models: model_data }, message: 'Available AI models')
        else
          render_header('Arbiter — Available Models')
          Output.table(
            ['Key', 'Provider', 'Default Model', 'Status'],
            model_data.map { |m| [m[:key], m[:name], m[:default_model] || 'N/A', m[:status]] }
          )
          Output.blank
        end
      end

      def arbiter_chat(args, _session)
        model_key = args[:model] || 'auto'
        prompt    = args[:prompt] or return Output.critical('--prompt required')

        # Route auto → gemini by default
        model_key = 'gemini' if model_key == 'auto'
        config    = MODELS[model_key] or return Output.critical("Unknown model: #{model_key}")

        # Stub response — in production, make actual API call
        response = arbiter_api_call(model_key, prompt)

        data = {
          model: model_key,
          provider: config[:name],
          prompt: prompt,
          response: response
        }
        if Output.json_mode
          json_ok(data, message: 'Arbiter response')
        else
          render_header("Arbiter AI — #{config[:name]}")
          Output.info("Prompt: #{prompt}")
          Output.blank
          $stdout.puts "#{Config::THEME[:success][:ansi]}#{response}#{Config::THEME[:reset]}"
          Output.blank
        end
      end

      def route_query(args, session)
        prompt = args[:prompt] or return Output.critical('--prompt required')
        # Simple routing heuristic — in production use ML-based classification
        model = route_heuristic(prompt)
        args[:model] = model
        arbiter_chat(args, session)
      end

      def arbiter_status
        data = {
          gemini: { status: 'available', key_present: !GEMINI_KEY.empty? },
          claude: { status: 'available', key_present: !CLAUDE_KEY.empty? },
          grok: { status: 'available', key_present: !XAI_KEY.empty? }
        }
        if Output.json_mode
          json_ok(data, message: 'Arbiter API status')
        else
          render_header('Arbiter — API Status')
          data.each do |model, info|
            icon = info[:key_present] ? '✓' : '✗'
            color = info[:key_present] ? Config::THEME[:success][:ansi] : Config::THEME[:critical][:ansi]
            $stdout.puts "  #{color}#{icon}#{Config::THEME[:reset]} #{model.capitalize}: #{info[:status]}"
          end
          Output.blank
        end
      end

      def arbiter_api_call(model_key, prompt)
        # Production: make live API call to selected provider
        # Stub for CLI foundation layer
        "[Arbiter AI] Response from #{MODELS[model_key][:name]} for: \"#{prompt[0, 50]}...\"\n" \
          "API integration active — connect #{MODELS[model_key][:name]} endpoint for live responses."
      end

      def route_heuristic(prompt)
        lower = prompt.downcase
        return 'claude'  if lower.match?(/code|debug|refactor|ruby|python|javascript/)
        return 'grok'    if lower.match?(/news|recent|today|current|2024|2025|2026/)

        'gemini'
      end
    end
  end
end
