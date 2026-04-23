# frozen_string_literal: true

module LaunchCore
  module Products
    # Product 4: Command-Portal — Internal Operations Hub
    class Portal < Base
      def execute(args, session:)
        sub = args[:sub] || args[:action]

        case sub&.to_s
        when 'dashboard' then portal_dashboard(session)
        when 'api'       then portal_api(session)
        when 'finance'   then portal_finance(session)
        when 'timeclock' then portal_timeclock(args, session)
        else                  portal_overview
        end
      end

      private

      def portal_overview
        data = {
          product: 'Command-Portal',
          description: 'Internal operations hub for company administrators',
          modules: {
            'dashboard' => 'Company overview & metrics',
            'api' => 'API vault and credential management',
            'finance' => 'Financial nexus (Privacy.com/Banking)',
            'timeclock' => 'Staff time tracking (Lark sync)'
          }
        }
        if Output.json_mode
          json_ok(data)
        else
          render_header
          Output.info("Internal Operations Hub for #{Config::COMPANY_NAME}")
          Output.blank
          data[:modules].each { |mod, desc| Output.muted("  /portal --sub=#{mod}    #{desc}") }
          Output.blank
        end
      end

      def portal_dashboard(_session)
        user_count    = Database::Models.users.count
        company_count = Database::Models.companies.count
        session_count = Database::Models.sessions.where(revoked: 0).count
        audit_count   = Database::Models.audit_log.count

        data = {
          users: user_count,
          companies: company_count,
          active_sessions: session_count,
          audit_events: audit_count,
          platform: "LaunchCore Command v#{LaunchCore::VERSION}"
        }

        if Output.json_mode
          json_ok(data, message: 'Portal dashboard')
        else
          render_header('Command-Portal — Dashboard')
          Output.table(
            %w[Metric Value],
            [['Total Users', user_count], ['Companies', company_count],
             ['Active Sessions', session_count], ['Audit Events', audit_count]]
          )
          Output.blank
        end
      end

      def portal_api(_session)
        data = {
          note: 'API credentials are managed in the LaunchCloud Labs secure vault',
          portal: "https://#{Config::DOMAIN}"
        }
        if Output.json_mode
          json_ok(data, message: 'API vault reference')
        else
          render_header('Command-Portal — API Vault')
          Output.info('Credentials are stored in the LCL secure vault.')
          Output.muted("Access: https://#{Config::DOMAIN}/portal/api")
          Output.blank
        end
      end

      def portal_finance(_session)
        data = { module: 'Financial Nexus', status: 'active', provider: 'Privacy.com / Mercury' }
        if Output.json_mode
          json_ok(data, message: 'Financial nexus')
        else
          render_header('Command-Portal — Finance')
          Output.info('Provider: Privacy.com / Mercury Banking')
          Output.muted("Access via web portal at https://#{Config::DOMAIN}/portal/finance")
          Output.blank
        end
      end

      def portal_timeclock(args, _session)
        action = args[:action2] || 'status'
        data   = { module: 'Timeclock', action: action, provider: 'Lark Sync', status: 'synced' }
        if Output.json_mode
          json_ok(data, message: "Timeclock: #{action}")
        else
          render_header('Command-Portal — Timeclock')
          Output.info('Lark integration: Active')
          Output.info("Action: #{action}")
          Output.muted('Clock-in/out syncs to Lark Base automatically.')
          Output.blank
        end
      end
    end
  end
end
