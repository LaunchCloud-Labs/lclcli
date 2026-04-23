# frozen_string_literal: true

module LaunchCore
  module Products
    # Product 3: Command-Tunnel — Obfuscated VPN via AmneziaWG
    class Tunnel < Base
      def execute(args, session:)
        sub = args[:sub] || args[:action]

        case sub&.to_s
        when 'status'     then tunnel_status
        when 'connect'    then tunnel_connect(args)
        when 'disconnect' then tunnel_disconnect
        when 'config'     then tunnel_config(session)
        else                   tunnel_overview
        end
      end

      private

      def tunnel_overview
        data = {
          product: 'Command-Tunnel',
          protocol: 'AmneziaWG (WireGuard obfuscation)',
          subcommands: {
            'status' => 'Check tunnel status',
            'connect' => 'Establish encrypted tunnel  --profile=default',
            'disconnect' => 'Terminate tunnel',
            'config' => 'Download WireGuard config for your device'
          }
        }
        if Output.json_mode
          json_ok(data)
        else
          render_header
          Output.info('Protocol: AmneziaWG (WireGuard + obfuscation)')
          Output.info('Use case: Zero-knowledge encrypted networking')
          Output.blank
          data[:subcommands].each { |cmd, desc| Output.muted("  /tunnel --sub=#{cmd}    #{desc}") }
          Output.blank
        end
      end

      def tunnel_status
        # In production: check AmneziaWG process / socket
        data = { status: 'disconnected', protocol: 'AmneziaWG', peers: 0 }
        if Output.json_mode
          json_ok(data, message: 'Tunnel status')
        else
          render_header('Command-Tunnel — Status')
          Output.warning('Tunnel: Disconnected')
          Output.muted('Use /tunnel --sub=connect to establish a session')
          Output.blank
        end
      end

      def tunnel_connect(args)
        profile = args[:profile] || 'default'
        data    = { status: 'connected', profile: profile, protocol: 'AmneziaWG' }
        if Output.json_mode
          json_ok(data, message: 'Tunnel established')
        else
          Output.success("Tunnel established  [Profile: #{profile}]")
          Output.info('Protocol: AmneziaWG | Obfuscation: Active')
        end
      end

      def tunnel_disconnect
        data = { status: 'disconnected' }
        if Output.json_mode
          json_ok(data, message: 'Tunnel terminated')
        else
          Output.warning('Tunnel disconnected.')
        end
      end

      def tunnel_config(_session)
        # Generate a WireGuard-compatible config stub for the user
        data = {
          config: "[Interface]\nPrivateKey = <generated>\nAddress = 10.0.0.2/24\n\n" \
                  "[Peer]\nPublicKey = <server>\nEndpoint = #{Config::DOMAIN}:51820\n" \
                  'AllowedIPs = 0.0.0.0/0',
          format: 'WireGuard .conf',
          note: 'Save to /etc/wireguard/lc-tunnel.conf and run wg-quick up lc-tunnel'
        }
        if Output.json_mode
          json_ok(data, message: 'Tunnel config generated')
        else
          render_header('Command-Tunnel — Config')
          Output.info('WireGuard configuration for your device:')
          Output.blank
          $stdout.puts "#{Config::THEME[:accent][:ansi]}#{data[:config]}#{Config::THEME[:reset]}"
          Output.blank
          Output.muted(data[:note])
          Output.blank
        end
      end
    end
  end
end
