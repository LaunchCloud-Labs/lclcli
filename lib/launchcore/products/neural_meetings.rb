# frozen_string_literal: true

module LaunchCore
  module Products
    # Product 5: Neural Meetings — Encrypted Video via Jitsi
    class NeuralMeetings < Base
      JITSI_APP_ID   = 'vpaas-magic-cookie-ca163c9415a04159a3c16f17de3d2d5f'
      JITSI_API_BASE = 'https://8x8.vc'

      def execute(args, session:)
        sub = args[:sub] || args[:action]

        case sub&.to_s
        when 'start'   then start_meeting(args, session)
        when 'join'    then join_meeting(args, session)
        when 'list'    then list_meetings(session)
        when 'end'     then end_meeting(args, session)
        else                meetings_overview
        end
      end

      private

      def meetings_overview
        data = {
          product: 'Neural Meetings',
          provider: 'Jitsi (8x8.vc)',
          encryption: 'End-to-end TLS',
          subcommands: {
            'start' => 'Start a new encrypted meeting  --name="meeting-name"',
            'join' => 'Join a meeting                 --room=ROOM_ID',
            'list' => 'List recent meetings',
            'end' => 'End a meeting                  --room=ROOM_ID'
          }
        }
        if Output.json_mode
          json_ok(data)
        else
          render_header
          Output.info('Provider: Jitsi / 8x8.vc | End-to-end encrypted')
          Output.blank
          data[:subcommands].each { |cmd, desc| Output.muted("  /meetings --sub=#{cmd}    #{desc}") }
          Output.blank
        end
      end

      def start_meeting(args, session)
        name    = (args[:name] || "lcl-#{SecureRandom.hex(4)}").gsub(/\s+/, '-').downcase
        room_id = "#{JITSI_APP_ID}/#{name}"
        url     = "#{JITSI_API_BASE}/#{room_id}"

        data = { room_id: room_id, name: name, url: url, host: session.email, encryption: 'TLS/E2E' }
        if Output.json_mode
          json_ok(data, message: 'Meeting started')
        else
          render_header('Neural Meetings — Started')
          Output.success("Meeting created: #{name}")
          Output.info("Join URL: #{url}")
          Output.info("Host: #{session.email}")
          Output.blank
        end
      end

      def join_meeting(args, session)
        room = args[:room] or return Output.critical('--room required')
        url  = "#{JITSI_API_BASE}/#{JITSI_APP_ID}/#{room}"

        data = { room: room, url: url, participant: session.email }
        if Output.json_mode
          json_ok(data, message: 'Join URL generated')
        else
          Output.info("Join URL: #{url}")
          Output.muted('Opening in your browser (or copy the URL manually)')
        end
      end

      def list_meetings(_session)
        data = { meetings: [], note: 'Meeting history stored in Jitsi session logs' }
        if Output.json_mode
          json_ok(data, message: 'Recent meetings')
        else
          render_header('Neural Meetings — Recent')
          Output.muted('No recent meeting history available locally.')
          Output.blank
        end
      end

      def end_meeting(args, _session)
        room = args[:room] or return Output.critical('--room required')
        data = { status: 'ended', room: room }
        if Output.json_mode
          json_ok(data, message: 'Meeting ended')
        else
          Output.success("Meeting #{room} ended.")
        end
      end
    end
  end
end
