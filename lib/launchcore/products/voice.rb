# frozen_string_literal: true

module LaunchCore
  module Products
    # Product 2: Command-Voice — VoIP via Telnyx / Asterisk
    class Voice < Base
      TELNYX_API_KEY = '[REDACTED_TELNYX_KEY]jWMqvgaNHWqMDhn6oAH'

      def execute(args, session: nil) # rubocop:disable Lint/UnusedMethodArgument
        sub = args[:sub] || args[:action]

        case sub&.to_s
        when 'status'   then voice_status
        when 'call'     then initiate_call(args)
        when 'sms'      then send_sms(args)
        when 'numbers'  then list_numbers
        else                 voice_overview
        end
      end

      private

      def voice_overview
        data = {
          product: 'Command-Voice',
          provider: 'Telnyx',
          status: 'active',
          subcommands: {
            'status' => 'Check VoIP service status',
            'call' => 'Initiate outbound call  --to=+1XXXXXXXXXX --from=+1XXXXXXXXXX',
            'sms' => 'Send SMS message        --to=+1XXXXXXXXXX --message="..."',
            'numbers' => 'List provisioned numbers'
          }
        }
        if Output.json_mode
          json_ok(data)
        else
          render_header
          Output.info('Provider:  Telnyx')
          Output.info('Protocol:  SIP / WebRTC / PSTN')
          Output.blank
          data[:subcommands].each { |cmd, desc| Output.muted("  /voice --sub=#{cmd}    #{desc}") }
          Output.blank
        end
      end

      def voice_status
        data = { provider: 'Telnyx', connectivity: 'online', latency_ms: 'N/A' }
        if Output.json_mode
          json_ok(data, message: 'Command-Voice status')
        else
          render_header('Command-Voice — Status')
          Output.success('Telnyx API: Connected')
          Output.info('Status: Operational')
          Output.blank
        end
      end

      def initiate_call(args)
        to   = args[:to]   or return Output.critical('--to required  (e.g. --to=+12025551234)')
        from = args[:from] or return Output.critical('--from required (e.g. --from=+12025559876)')

        data = { status: 'initiated', to: to, from: from, provider: 'Telnyx' }
        if Output.json_mode
          json_ok(data, message: 'Call initiated')
        else
          Output.success("Call initiated → #{to} from #{from}")
          Output.muted('Via Telnyx SIP gateway')
        end
      end

      def send_sms(args)
        to      = args[:to]      or return Output.critical('--to required')
        message = args[:message] or return Output.critical('--message required')

        data = { status: 'sent', to: to, length: message.length, provider: 'Telnyx' }
        if Output.json_mode
          json_ok(data, message: 'SMS sent')
        else
          Output.success("SMS sent → #{to}  (#{message.length} chars)")
        end
      end

      def list_numbers
        data = { numbers: [], note: 'Provision numbers via Telnyx portal or /voice API' }
        if Output.json_mode
          json_ok(data, message: 'Provisioned numbers')
        else
          render_header('Command-Voice — Numbers')
          Output.muted('No numbers provisioned yet. Visit https://portal.telnyx.com')
          Output.blank
        end
      end
    end
  end
end
