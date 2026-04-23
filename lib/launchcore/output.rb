module LaunchCore
  module Output
    class << self
      attr_accessor :json_mode

      # Formatting Constants
      CYAN   = "\e[36m"
      GREEN  = "\e[32m"
      RED    = "\e[31m"
      BLUE   = "\e[34m"
      MUTED  = "\e[90m"
      BOLD   = "\e[1m"
      RESET  = "\e[0m"

      def header(text)
        puts "\n#{BOLD}#{BLUE}" + "━" * 60 + "#{RESET}"
        puts "  #{BOLD}#{CYAN}#{text.upcase}#{RESET}"
        puts "#{BOLD}#{BLUE}" + "━" * 60 + "#{RESET}"
      end

      def primary(msg) ; puts "  #{CYAN}#{msg}#{RESET}" ; end
      def success(msg) ; puts "  #{GREEN}✓#{RESET} #{msg}" ; end
      def info(msg)    ; puts "  #{BLUE}›#{RESET} #{msg}" ; end
      def warning(msg) ; puts "  #{RED}⚠#{RESET} #{msg}" ; end
      def critical(msg); puts "  #{BOLD}#{RED}✘#{RESET} #{msg}" ; end
      def muted(msg)   ; puts "  #{MUTED}#{msg}#{RESET}" ; end
      def blank        ; puts ; end
      def separator    ; puts "#{MUTED}" + "─" * 60 + "#{RESET}" ; end
      def divider(char, color=:muted); puts "#{MUTED}" + char * 60 + "#{RESET}" ; end

      def json_response(**data)
        data[:timestamp] = Time.now.utc.iso8601
        $stdout.puts JSON.generate(data)
      end
      
      def splash
        puts "#{CYAN}#{BOLD}"
        puts "  _                               _      ____"
        puts " | |    __ _ _   _ _ __   ___ ___| | ___|  _ \\"
        puts " | |   / _' | | | | '_ \\ / __/ _ \\ |/ _ \\ |_) |"
        puts " | |__| (_| | |_| | | | | (_|  __/ |  __/  _ <"
        puts " |_____\\__,_|\\__,_|_| |_|\\___\___|_|\\___|_| \\_\\"
        puts "#{RESET}"
        puts "        #{BLUE}LaunchCore Command Center v#{VERSION}#{RESET}"
        puts "        #{MUTED}Sovereign Business Operating System#{RESET}"
        puts "  " + "#{BLUE}━" * 60 + "#{RESET}"
      end
    end
  end
end
