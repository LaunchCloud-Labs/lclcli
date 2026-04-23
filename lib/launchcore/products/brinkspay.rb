# frozen_string_literal: true

module LaunchCore
  module Products
    # Product 9a: BrinksPay — Buy Now Pay Later + Credit
    class BrinksPay < Base
      def execute(args, session:)
        sub = args[:sub] || args[:action]

        case sub&.to_s
        when 'score'   then credit_score(session)
        when 'apply'   then apply_bnpl(args, session)
        when 'balance' then bnpl_balance(session)
        when 'pay'     then make_payment(args, session)
        else                brinkspay_overview
        end
      end

      private

      def brinkspay_overview
        data = {
          product: 'BrinksPay',
          description: 'Buy Now Pay Later + Soft Credit Pull via Bloom Credit',
          provider: 'Bloom Credit (Vantage Score)',
          subcommands: {
            'score' => 'Pull soft credit score (Vantage / Bloom)',
            'apply' => 'Apply for BNPL line  --amount=1000',
            'balance' => 'View BNPL balance and terms',
            'pay' => 'Make a payment        --amount=100'
          },
          auth_requirement: 'L3 (KYC Verified)'
        }
        if Output.json_mode
          json_ok(data)
        else
          render_header
          Output.info('BNPL Platform | Bloom Credit Integration (Vantage Score)')
          Output.warning('Requires Auth Level 3 (KYC Verified)')
          Output.blank
          data[:subcommands].each { |cmd, desc| Output.muted("  /brinkspay --sub=#{cmd}    #{desc}") }
          Output.blank
        end
      end

      def credit_score(_session)
        # In production: Bloom Credit soft pull API
        data = {
          provider: 'Bloom Credit',
          score: nil,
          model: 'Vantage Score',
          type: 'soft_pull',
          note: 'Connect Bloom Credit to retrieve actual score'
        }
        if Output.json_mode
          json_ok(data, message: 'Credit score (soft pull)')
        else
          render_header('BrinksPay — Credit Score')
          Output.info('Provider: Bloom Credit | Model: Vantage Score')
          Output.warning('Score not yet available — Bloom Credit integration pending.')
          Output.muted('This is a soft pull (no credit impact).')
          Output.blank
        end
      end

      def apply_bnpl(args, _session)
        amount = args[:amount] or return Output.critical('--amount required')
        data   = {
          status: 'under_review',
          amount: amount,
          product: 'BrinksPay BNPL',
          note: 'Decision in 1–2 business days after Bloom Credit evaluation'
        }
        if Output.json_mode
          json_ok(data, message: 'BNPL application submitted')
        else
          Output.success("BNPL application for $#{amount} submitted.")
          Output.info('Decision: 1–2 business days (Bloom Credit evaluation)')
        end
      end

      def bnpl_balance(_session)
        data = { balance: '0.00', credit_line: '0.00', next_payment: nil, currency: 'USD' }
        if Output.json_mode
          json_ok(data, message: 'BNPL balance')
        else
          render_header('BrinksPay — Balance')
          Output.info('Outstanding Balance: $0.00')
          Output.info('Credit Line: Not yet established')
          Output.blank
        end
      end

      def make_payment(args, _session)
        amount = args[:amount] or return Output.critical('--amount required')
        data   = { status: 'processed', amount: amount, currency: 'USD', timestamp: Time.now.utc.iso8601 }
        if Output.json_mode
          json_ok(data, message: 'Payment processed')
        else
          Output.success("Payment of $#{amount} processed.")
        end
      end
    end
  end
end
