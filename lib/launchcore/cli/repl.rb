require 'readline'

module LaunchCore
  module CLI
    class REPL
      COMMANDS = %w[/help /status /payroll /auth/login /auth/signup /settings /admin /robot /ai /exit]

      def initialize
        @session = Auth::Session.new
        @session.auto_resume
        @dispatcher = Dispatcher.new(@session)
      end

      def run
        LaunchCore::Output.splash
        
        # Setup tab completion
        comp = proc { |s| COMMANDS.grep(/^#{Regexp.escape(s)}/) }
        Readline.completion_append_character = " "
        Readline.completion_proc = comp

        loop do
          prompt = "\e[1m\e[34mlc \e[36m>\e[0m "
          input = Readline.readline(prompt, true)
          
          break if input.nil? || input == '/exit' || input == 'exit'
          next if input.empty?

          begin
            @dispatcher.dispatch(input)
          rescue StandardError => e
            LaunchCore::Output.critical(e.message)
          end
        end
        puts "Goodbye!"
      end
    end
  end
end
