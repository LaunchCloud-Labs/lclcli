# frozen_string_literal: true

module LaunchCore
  module Products
    # Product 6: Workforce Module — Recruitment & HR Engine
    class Workforce < Base
      def execute(args, session:)
        sub = args[:sub] || args[:action]

        case sub&.to_s
        when 'applicants' then list_applicants(session)
        when 'invite'     then send_applicant_invite(args, session)
        when 'roster'     then company_roster(session)
        else                   workforce_overview
        end
      end

      private

      def workforce_overview
        data = {
          product: 'Workforce Module',
          description: 'Recruitment engine with Lark integration',
          subcommands: {
            'applicants' => 'View applicant pipeline',
            'invite' => 'Send applicant invite  --email=... --role=...',
            'roster' => 'View current company roster'
          }
        }
        if Output.json_mode
          json_ok(data)
        else
          render_header
          Output.info('Recruitment Engine | Lark-Backed Persistent Storage')
          Output.blank
          data[:subcommands].each { |cmd, desc| Output.muted("  /workforce --sub=#{cmd}    #{desc}") }
          Output.blank
        end
      end

      def list_applicants(_session)
        data = { applicants: [], note: 'Applicant data synced from Lark Base vault' }
        if Output.json_mode
          json_ok(data, message: 'Applicant pipeline')
        else
          render_header('Workforce — Applicant Pipeline')
          Output.muted('No applicants loaded locally. Data lives in Lark Base.')
          Output.blank
        end
      end

      # rubocop:disable Metrics/PerceivedComplexity
      def send_applicant_invite(args, session)
        email = args[:email] or return Output.critical('--email required')
        role  = args[:role] || 'company_agent'

        code = Auth::Authenticator.generate_invite!(
          created_by_id: session.user_id,
          email: email,
          role: role,
          company_id: session.claims&.dig('company_id')
        )

        data = { invite_code: code, email: email, role: role }
        if Output.json_mode
          json_ok(data, message: 'Invite sent')
        else
          Output.success("Invite sent to #{email}  (code: #{code})")
          Output.info("Role: #{Config::USER_CLASSES[role] || role}")
        end
      rescue Auth::AuthError => e
        Output.json_mode ? json_error(e.message) : Output.critical(e.message)
      end
      # rubocop:enable Metrics/PerceivedComplexity

      # rubocop:disable Metrics/PerceivedComplexity
      def company_roster(session)
        company_id = session.claims&.dig('company_id')
        users      = company_id ? Database::Models.users.where(company_id: company_id).all : []
        data       = users.map { |u| { id: u[:id], email: u[:email], class: u[:user_class], level: u[:auth_level] } }

        if Output.json_mode
          json_ok({ roster: data }, message: 'Company roster')
        else
          render_header('Workforce — Company Roster')
          if data.empty?
            Output.muted('No team members found.')
          else
            Output.table(%w[ID Email Class Level], data.map do |u|
              [u[:id], u[:email], u[:class], "L#{u[:level]}"]
            end)
          end
          Output.blank
        end
      end
      # rubocop:enable Metrics/PerceivedComplexity
    end
  end
end
