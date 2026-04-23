# frozen_string_literal: true

module LaunchCore
  module Products
    # Product 10: Stophold — JIT (Just-In-Time) Travel Funding
    class Stophold < Base
      def execute(args, session:)
        sub = args[:sub] || args[:action]

        case sub&.to_s
        when 'request' then request_funding(args, session)
        when 'status'  then funding_status(session)
        when 'history' then funding_history(session)
        else                stophold_overview
        end
      end

      private

      def stophold_overview
        data = {
          product: 'Stophold',
          description: 'Just-In-Time travel funding with real-time approval',
          subcommands: {
            'request' => 'Request JIT funding  --amount=500 --purpose="travel"',
            'status' => 'Check funding request status',
            'history' => 'View funding history'
          },
          auth_requirement: 'L4 (30-Day Active + KYC Verified)'
        }
        if Output.json_mode
          json_ok(data)
        else
          render_header
          Output.info('Just-In-Time Travel Funding')
          Output.warning('Requires Auth Level 4 (30-Day Active Account + L1-L3)')
          Output.blank
          data[:subcommands].each { |cmd, desc| Output.muted("  /stophold --sub=#{cmd}    #{desc}") }
          Output.blank
        end
      end

      def request_funding(args, _session)
        amount  = args[:amount] or return Output.critical('--amount required')
        purpose = args[:purpose] || 'travel'

        request_id = "SH-#{SecureRandom.hex(8).upcase}"
        data = {
          request_id: request_id,
          status: 'pending_approval',
          amount: amount,
          purpose: purpose,
          currency: 'USD',
          submitted: Time.now.utc.iso8601,
          note: 'JIT approval typically within minutes during business hours'
        }
        if Output.json_mode
          json_ok(data, message: 'Funding request submitted')
        else
          Output.success("JIT funding request submitted  (ID: #{request_id})")
          Output.info("Amount: $#{amount}  |  Purpose: #{purpose}")
          Output.muted('Approval: Typically within minutes during business hours')
        end
      end

      def funding_status(_session)
        data = { requests: [], note: 'No active funding requests' }
        if Output.json_mode
          json_ok(data, message: 'Funding status')
        else
          render_header('Stophold — Funding Status')
          Output.muted('No active funding requests.')
          Output.blank
        end
      end

      def funding_history(_session)
        data = { history: [], total_funded: '0.00', currency: 'USD' }
        if Output.json_mode
          json_ok(data, message: 'Funding history')
        else
          render_header('Stophold — Funding History')
          Output.muted('No funding history found.')
          Output.blank
        end
      end
    end
  end
end
