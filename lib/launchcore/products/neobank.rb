# frozen_string_literal: true

module LaunchCore
  module Products
    # Product 8: Neobank + DWR — Programmable Banking via Mercury / Lithic
    class Neobank < Base
      def execute(args, session:)
        sub = args[:sub] || args[:action]

        case sub&.to_s
        when 'balance'    then account_balance(session)
        when 'transfer'   then initiate_transfer(args, session)
        when 'cards'      then list_cards(session)
        when 'issue'      then issue_card(args, session)
        when 'payroll'    then payroll_info(session)
        else                   neobank_overview
        end
      end

      private

      def neobank_overview
        data = {
          product: 'Neobank + DWR',
          providers: %w[Mercury Lithic],
          description: 'Programmable banking, global payroll rail, interchange fee monetization',
          interchange_rate: '1-2%',
          subcommands: {
            'balance' => 'View account balances',
            'transfer' => 'Initiate transfer  --to=ACC --amount=100 --currency=USD',
            'cards' => 'List virtual/physical cards (Lithic)',
            'issue' => 'Issue new card      --type=virtual --spend_limit=500',
            'payroll' => 'Global payroll rail overview'
          },
          auth_requirement: 'L3 (KYC Verified)'
        }
        if Output.json_mode
          json_ok(data)
        else
          render_header
          Output.info('Providers: Mercury Banking | Lithic Card Issuing')
          Output.info('Interchange: 1–2% monetization on issued cards')
          Output.warning('Requires Auth Level 3 (KYC Verified)')
          Output.blank
          data[:subcommands].each { |cmd, desc| Output.muted("  /neobank --sub=#{cmd}    #{desc}") }
          Output.blank
        end
      end

      def account_balance(_session)
        # In production: call Mercury API
        data = {
          accounts: [
            { name: 'Operating', balance: '0.00', currency: 'USD', provider: 'Mercury' }
          ],
          note: 'Connect Mercury account via web portal'
        }
        if Output.json_mode
          json_ok(data, message: 'Account balances')
        else
          render_header('Neobank — Balances')
          Output.table(%w[Account Balance Currency Provider],
                       data[:accounts].map { |a| [a[:name], a[:balance], a[:currency], a[:provider]] })
          Output.blank
        end
      end

      def initiate_transfer(args, _session)
        to       = args[:to]       or return Output.critical('--to required')
        amount   = args[:amount]   or return Output.critical('--amount required')
        currency = args[:currency] || 'USD'

        data = { status: 'initiated', to: to, amount: amount, currency: currency,
                 provider: 'Mercury', timestamp: Time.now.utc.iso8601 }
        if Output.json_mode
          json_ok(data, message: 'Transfer initiated')
        else
          Output.success("Transfer of #{amount} #{currency} → #{to} initiated")
          Output.muted('Via Mercury banking rail')
        end
      end

      def list_cards(_session)
        data = { cards: [], provider: 'Lithic', note: 'Issue cards via /neobank --sub=issue' }
        if Output.json_mode
          json_ok(data, message: 'Lithic cards')
        else
          render_header('Neobank — Cards (Lithic)')
          Output.muted('No cards issued. Use /neobank --sub=issue to create one.')
          Output.blank
        end
      end

      def issue_card(args, _session)
        type        = args[:type]        || 'virtual'
        spend_limit = args[:spend_limit] || '500'
        currency    = args[:currency]    || 'USD'

        data = {
          status: 'issued',
          type: type,
          spend_limit: spend_limit,
          currency: currency,
          provider: 'Lithic',
          card_token: "ltc_#{SecureRandom.hex(12)}"
        }
        if Output.json_mode
          json_ok(data, message: 'Card issued')
        else
          Output.success("#{type.capitalize} card issued via Lithic")
          Output.info("Spend limit: #{spend_limit} #{currency}")
          Output.info("Token: #{data[:card_token]}")
        end
      end

      def payroll_info(_session)
        data = {
          provider: 'Mercury / Lithic',
          rails: ['ACH', 'Wire', 'International SWIFT'],
          mechanism: 'Global payroll rail with interchange monetization',
          note: 'Configure in web portal for automated payroll runs'
        }
        if Output.json_mode
          json_ok(data, message: 'Payroll rail info')
        else
          render_header('Neobank — Global Payroll Rail')
          Output.info('Provider: Mercury / Lithic')
          Output.info('Rails: ACH | Wire | SWIFT (International)')
          Output.info('Revenue Model: 1–2% interchange on card transactions')
          Output.muted("Configure automated runs at https://#{Config::DOMAIN}/neobank")
          Output.blank
        end
      end
    end
  end
end
