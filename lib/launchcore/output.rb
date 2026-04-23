# frozen_string_literal: true

module LaunchCore
  # Centralised ANSI output — honours --json mode globally
  module Output
    T = Config::THEME

    class << self
      attr_accessor :json_mode, :silent_mode

      def success(msg)   = print_line(T[:success][:ansi], '✓', msg)
      def warning(msg)   = print_line(T[:warning][:ansi], '⚠', msg)
      def critical(msg)  = print_line(T[:critical][:ansi], '✗', msg)
      def info(msg)      = print_line(T[:accent][:ansi],   '›', msg)
      def muted(msg)     = print_line(T[:muted][:ansi],    ' ', msg)
      def primary(msg)   = print_line(T[:primary][:ansi],  '◆', msg)

      def header(msg)
        return if silent_mode

        width = 70
        bar = "#{T[:primary][:ansi]}#{T[:bold]}#{'═' * width}#{T[:reset]}"
        $stdout.puts bar
        $stdout.puts "#{T[:primary][:ansi]}#{T[:bold]} #{msg.center(width - 2)} #{T[:reset]}"
        $stdout.puts bar
      end

      def divider(char = '─', color = :muted)
        return if silent_mode

        $stdout.puts "#{T[color][:ansi]}#{char * 70}#{T[:reset]}"
      end

      def table(headers, rows)
        return if silent_mode

        col_widths = headers.map.with_index { |h, i| [h.length, rows.map { |r| r[i].to_s.length }.max || 0].max }
        header_row = headers.map.with_index do |h, i|
          h.ljust(col_widths[i])
        end.join("  #{T[:muted][:ansi]}│#{T[:reset]}  ")
        $stdout.puts "#{T[:primary][:ansi]}#{T[:bold]}  #{header_row}#{T[:reset]}"
        divider
        rows.each do |row|
          line = row.map.with_index do |cell, i|
            cell.to_s.ljust(col_widths[i])
          end.join("  #{T[:muted][:ansi]}│#{T[:reset]}  ")
          $stdout.puts "  #{line}"
        end
      end

      def json_response(status:, message:, data: nil, command: nil, **extra)
        payload = { status: status, message: message, timestamp: Time.now.utc.iso8601 }
        payload[:command] = command if command
        payload[:data]    = data    if data
        payload.merge!(extra)
        $stdout.puts JSON.generate(payload)
        payload
      end

      def prompt_field(label, secret: false)
        $stdout.print "  #{T[:accent][:ansi]}#{label}#{T[:reset]}: "
        if secret
          system('stty -echo')
          val = $stdin.gets.to_s.chomp
          system('stty echo')
          $stdout.puts
          val
        else
          $stdin.gets.to_s.chomp
        end
      end

      def confirm?(prompt)
        $stdout.print "  #{T[:warning][:ansi]}#{prompt} [y/N]#{T[:reset]}: "
        $stdin.gets.to_s.chomp.downcase == 'y'
      end

      def blank
        $stdout.puts unless silent_mode
      end

      private

      def print_line(color, icon, msg)
        return if silent_mode

        $stdout.puts "  #{color}#{T[:bold]}#{icon}#{T[:reset]} #{msg}"
      end
    end

    self.json_mode   = false
    self.silent_mode = false
  end
end
