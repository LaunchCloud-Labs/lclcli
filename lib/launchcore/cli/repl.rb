# frozen_string_literal: true

require 'reline'

module LaunchCore
  module CLI
    class REPL
      T = Config::THEME

      HISTORY_LIMIT = Config::HISTORY_LIMIT

      def initialize
        @session    = Auth::Session.new
        @dispatcher = Dispatcher.new(@session)
        setup_reline
      end

      # Main entry point
      def run
        compact = begin
          $stdout.winsize[1] < 120
        rescue StandardError
          false
        end
        Splash.render(compact: compact)
        @session.auto_resume

        loop do
          prompt = build_prompt
          line   = Reline.readline(prompt, true)

          break if line.nil? # EOF / Ctrl-D

          line = line.strip
          next if line.empty?

          save_history(line)
          process(line)
        end

        persist_history
        Output.blank
        Output.muted('Session preserved. Goodbye.')
      rescue Interrupt
        persist_history
        Output.blank
        Output.muted('Interrupted. Goodbye.')
      end

      COMPLETIONS = %w[
        /auth/login /auth/logout /auth/signup /auth/invite
        /settings /settings/2fa /settings/kyc /settings/password /settings/profile
        /help /status
        /voice /tunnel /portal /meetings /workforce
        /scheduler /neobank /brinkspay /tradeshield /stophold /arbiter
        exit quit
      ].freeze

      private

      # --------- Input processing ---------

      def process(line)
        if line.start_with?('/')
          @dispatcher.dispatch(line)
        elsif line =~ /\A(exit|quit|bye)\z/i
          @dispatcher.dispatch('/auth/logout')
          exit(0)
        else
          Output.warning('Unknown input. Commands start with /  — try /help')
        end
      rescue Auth::AuthError => e
        Output.critical(e.message)
      rescue StandardError => e
        Output.critical("Unexpected error: #{e.message}")
        Output.muted(e.backtrace&.first(3)&.join("\n  "))
      end

      # --------- Prompt ---------

      def build_prompt
        if @session.authenticated?
          level_color = level_color_for(@session.auth_level)
          "#{T[:primary][:ansi]}#{T[:bold]}[lc]#{T[:reset]} " \
            "#{T[:success][:ansi]}#{@session.email}#{T[:reset]} " \
            "#{level_color}L#{@session.auth_level}#{T[:reset]} " \
            "#{T[:accent][:ansi]}→#{T[:reset]} "
        else
          "#{T[:primary][:ansi]}#{T[:bold]}[lc]#{T[:reset]} " \
            "#{T[:warning][:ansi]}[guest]#{T[:reset]} " \
            "#{T[:muted][:ansi]}→#{T[:reset]} "
        end
      end

      def level_color_for(level)
        case level
        when 4 then T[:success][:ansi]
        when 3 then T[:primary][:ansi]
        when 2 then T[:accent][:ansi]
        else        T[:warning][:ansi]
        end
      end

      # --------- reline setup ---------

      def setup_reline
        Reline.completion_proc = method(:tab_complete)
        Reline.completion_append_character = ' '
        load_history_into_reline
      end

      def tab_complete(input)
        COMPLETIONS.select { |c| c.start_with?(input) }
      end

      # --------- History ---------

      def load_history_into_reline
        return unless File.exist?(Config::HISTORY_FILE)

        lines = File.readlines(Config::HISTORY_FILE, chomp: true).last(HISTORY_LIMIT)
        lines.each { |l| Reline::HISTORY.push(l) unless l.empty? }
      rescue StandardError
        nil
      end

      def save_history(line)
        @history_buffer ||= []
        @history_buffer << line unless @history_buffer.last == line
      end

      def persist_history
        existing = if File.exist?(Config::HISTORY_FILE)
                     File.readlines(Config::HISTORY_FILE, chomp: true)
                   else
                     []
                   end
        combined = (existing + (@history_buffer || [])).last(HISTORY_LIMIT)
        File.write(Config::HISTORY_FILE, "#{combined.join("\n")}\n")
      rescue StandardError
        nil
      end
    end
  end
end
