# frozen_string_literal: true

module LaunchCore
  module CLI
    # Routes slash commands to the correct handler
    class Dispatcher
      T = Config::THEME

      def initialize(session)
        @session = session
      end

      def dispatch(input, extra_args = [])
        parts   = input.strip.split + extra_args.reject { |a| a == '--json' }
        command = parts.shift.downcase
        args    = parse_args(parts)

        case command
        when '/help'           then cmd_help(args)
        when '/status'         then cmd_status(args)
        when '/auth/login'     then cmd_login(args)
        when '/auth/signup'    then cmd_signup(args)
        when '/auth/logout'    then cmd_logout
        when '/auth/invite'    then cmd_invite(args)
        when '/settings'       then cmd_settings(args)
        when '/admin'          then cmd_admin(args)
        when '/robot'          then cmd_robot(args)
        when '/update'         then cmd_update(args)
        when '/godmode'        then cmd_godmode(args)
        when '/voice'          then dispatch_product(:voice, args)
        when '/tunnel'         then dispatch_product(:tunnel, args)
        when '/portal'         then dispatch_product(:portal, args)
        when '/scheduler'      then dispatch_product(:scheduler, args)
        when '/payroll'        then dispatch_product(:payroll, args)
        when '/timeclock'      then dispatch_product(:timeclock, args)
        when '/employee'       then dispatch_product(:employee, args)
        when '/arbiter'        then dispatch_product(:arbiter, args)
        when /\A\/([a-z0-9_-]+)\z/
          # Dynamic Spoke Discovery
          spoke_key = Regexp.last_match(1)
          if system("command -v lcl-#{spoke_key} > /dev/null 2>&1")
            dispatch_product(spoke_key.to_sym, args)
          else
            unknown_command(command)
          end
        else
          unknown_command(command)
        end
      end

      private

      def unknown_command(command)
        result = { status: 'error', message: "Unknown command: #{command}. Try /help" }
        return Output.json_response(**result) if Output.json_mode
        Output.warning(result[:message])
        result
      end

      def cmd_help(_args)
        LaunchCore::Output.display_help
      end

      def cmd_status(_args)
        if @session.logged_in?
          claims = @session.current_user
          data = { email: claims['email'], auth_level: claims['auth_level'], class: claims['user_class'] }
          Output.json_mode ? Output.json_response(status: 'ok', data: data) : Output.success("Authenticated as #{data[:email]} (L#{data[:auth_level]})")
        else
          Output.warning("Not authenticated.")
        end
      end

      def cmd_login(args)
        email = args[:email] || Output.prompt_field('Email')
        pass = args[:password] || Output.prompt_field('Password', secret: true)
        user = Auth::Authenticator.login!(email: email, password: pass)
        token, = Auth::JWTManager.encode(user_id: user[:id], email: user[:email], user_class: user[:user_class], auth_level: user[:auth_level], entitlements: JSON.parse(user[:entitlements] || '{}'))
        @session.store!(token)
        Output.success("Welcome back, #{user[:first_name]}!")
      end

      def cmd_admin(args)
        @session.require_auth!(min_level: 4)
        if args[:provision]
          slug = args[:company] || args[:provision]
          owner_email = args[:owner]
          id = Database::Models.companies.insert(name: slug.upcase, slug: slug.upcase, status: 'active', entitlements: '{}', created_at: Time.now.utc.iso8601, updated_at: Time.now.utc.iso8601)
          Output.success("Provisioned #{slug} (ID: #{id})")
        elsif args[:grant]
          slug = args[:company]
          mod = args[:module]
          company = Database::Models.companies.where(slug: slug.upcase).first
          ents = JSON.parse(company[:entitlements] || '{}')
          ents[mod] = true
          Database::Models.companies.where(id: company[:id]).update(entitlements: JSON.generate(ents))
          Output.success("Granted #{mod} to #{slug}")
        elsif args[:onboarding]
          require_relative '../admin/onboarding'
          Admin::Onboarding.run(args, @session)
        else
          Output.info("Admin usage: /admin --provision=slug, /admin --grant=slug --module=m, /admin --onboarding")
        end
      end

      def cmd_godmode(_args)
        @session.require_auth!(min_level: 4)
        Output.header("GOD MODE: GLOBAL VIEW")
        Output.primary("Active Sessions:")
        Database::Models.sessions.where(revoked: 0).each { |s| puts "  - ID: #{s[:id]} | JTI: #{s[:jti][0..10]}..." }
        Output.primary("Companies:")
        Database::Models.companies.all.each { |c| puts "  - #{c[:slug]} | Status: #{c[:status]}" }
      end

      def cmd_update(_args)
        Output.header("Checking for Updates...")
        ['lclcli', 'lcl-payroll', 'LCL-TimeClock'].each do |repo|
          res = `cd ~/projects/#{repo} && git pull origin master 2>&1 || git pull origin main 2>&1`
          Output.info("#{repo}: #{res.strip.lines.last}")
        end
      end

      def dispatch_product(key, args)
        binary_name = "lcl-#{key}"
        # Trigger auto-install if missing but entitled
        unless system("command -v #{binary_name} > /dev/null 2>&1")
          if @session.entitlements[key.to_s] || @session.auth_level >= 4
            Output.info("Installing missing spoke: #{binary_name}")
            system("curl -sSL https://raw.githubusercontent.com/LaunchCloud-Labs/LaunchCore-Command-#{key.capitalize}/master/install.sh | bash")
          else
            Output.critical("Module #{key} requires subscription.")
            return
          end
        end

        # Reconstruct args string
        arg_str = args.map { |k, v| v == true ? "--#{k}" : "--#{k}=#{v}" }.join(' ')
        system("#{binary_name} #{arg_str} --auth-token=#{@session.token}")
      end

      def parse_args(parts)
        result = {}
        parts.each do |part|
          if part =~ /\A--([a-z_]+)(?:=(.+))?\z/
            result[Regexp.last_match(1).to_sym] = Regexp.last_match(2) || true
          end
        end
        result
      end
    end
  end
end
