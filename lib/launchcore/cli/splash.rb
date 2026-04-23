# frozen_string_literal: true

module LaunchCore
  module CLI
    # High-impact ASCII splash screen with Midnight Blurple theme
    module Splash
      T = Config::THEME

      LOGO = <<~'ASCII'
         ___       __  ___  ___  ___  ________  ___  ___  ________  ________  ________  ________  _______
        |\  \     |\  \|\  \|\  \|\  \|\   ___  \|\  \|\  \|\   ____\|\   __  \|\   __  \|\   __  \|\  ___ \
        \ \  \    \ \  \ \  \ \  \ \  \ \  \\ \  \ \  \\\  \ \  \___|\ \  \|\  \ \  \|\  \ \  \|\  \ \   __/|
         \ \  \    \ \  \ \  \ \  \ \  \ \  \\ \  \ \  \\\  \ \  \    \ \  \\\  \ \   _  _\ \   _  _\ \  \_|/__
          \ \  \____\ \  \ \  \ \  \ \  \ \  \\ \  \ \  \\\  \ \  \____\ \  \\\  \ \  \\  \\ \  \\  \\ \  \_|\ \
           \ \_______\ \__\ \_______\ \__\ \__\\ \__\ \_______\ \_______\ \_______\ \__\\ _\\ \__\\ _\\ \_______\
            \|_______|\|__|\|_______|\|__|\|__| \|__|\|_______|\|_______|\|_______|\|__|\|__|\|__|\|__|\|_______|
      ASCII

      BANNER_COMPACT = <<~ART
        ██╗      ██████╗
        ██║     ██╔════╝
        ██║     ██║
        ██║     ██║
        ███████╗╚██████╗
        ╚══════╝ ╚═════╝  LaunchCore Command
      ART

      def self.render(compact: false)
        $stdout.puts
        print_banner(compact)
        print_tagline
        print_status_bar
        $stdout.puts
      end

      def self.render_json
        {
          product: 'LaunchCore Command',
          version: LaunchCore::VERSION,
          codename: LaunchCore::CODENAME,
          domain: Config::DOMAIN
        }
      end

      def self.print_banner(compact)
        art = compact ? BANNER_COMPACT : LOGO
        art.each_line do |line|
          $stdout.puts "#{T[:primary][:ansi]}#{T[:bold]}#{line.chomp}#{T[:reset]}"
        end
      end

      def self.print_tagline
        tag = "  LaunchCore Command  v#{LaunchCore::VERSION} \"#{LaunchCore::CODENAME}\"  —  by LaunchCloud Labs"
        $stdout.puts "#{T[:accent][:ansi]}#{T[:bold]}#{tag}#{T[:reset]}"
        $stdout.puts "#{T[:muted][:ansi]}  #{Config::DOMAIN}  |  CLI-First. Zero-Trust. Production-Grade.#{T[:reset]}"
      end

      def self.print_status_bar
        $stdout.puts
        $stdout.puts(
          "  #{T[:muted][:ansi]}[#{T[:reset]}#{T[:success][:ansi]}#{T[:bold]} SYSTEM ONLINE #{T[:reset]}" \
          "#{T[:muted][:ansi]}]  #{T[:reset]}" \
          "#{T[:muted][:ansi]}Type #{T[:reset]}#{T[:accent][:ansi]}/help#{T[:reset]}" \
          "#{T[:muted][:ansi]} to begin  |  #{T[:reset]}#{T[:accent][:ansi]}/auth/login#{T[:reset]}" \
          "#{T[:muted][:ansi]} to authenticate#{T[:reset]}"
        )
      end
    end
  end
end
