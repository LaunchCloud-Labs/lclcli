module LaunchCore
  module Output
    T = Config::THEME
    class << self
      attr_accessor :json_mode

      def header(text)
        puts "\n\e[1m\e[34m" + "━" * 60 + "\e[0m"
        puts "  \e[1m\e[36m#{text.upcase}\e[0m"
        puts "\e[1m\e[34m" + "━" * 60 + "\e[0m"
      end

      def success(msg) ; puts "  \e[32m✓\e[0m #{msg}" ; end
      def info(msg)    ; puts "  \e[34m›\e[0m #{msg}" ; end
      def warning(msg) ; puts "  \e[33m⚠\e[0m #{msg}" ; end
      def critical(msg); puts "  \e[31m✘\e[0m #{msg}" ; end
      def separator    ; puts "\e[90m" + "─" * 60 + "\e[0m" ; end
      def blank; puts; end
      
      def splash
        puts "\e[36m\e[1m"
        puts "  _                               _      ____"
        puts " | |    __ _ _   _ _ __   ___ ___| | ___|  _ \\"
        puts " | |   / _' | | | | '_ \\ / __/ _ \\ |/ _ \\ |_) |"
        puts " | |__| (_| | |_| | | | | (_|  __/ |  __/  _ <"
        puts " |_____\\__,_|\\__,_|_| |_|\\___\___|_|\\___|_| \\_\\"
        puts "\e[0m"
        puts "        \e[34mLaunchCore Command Center v#{VERSION}\e[0m"
        puts "        \e[90mSovereign Business Operating System\e[0m"
        puts "  " + "━" * 60
      end
    end
  end
end
