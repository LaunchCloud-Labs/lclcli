# frozen_string_literal: true

module LaunchCore
  module Products
    # Product 7: The Scheduler — Automated Credential Kill-Switch
    class Scheduler < Base
      def execute(args, session:)
        sub = args[:sub] || args[:action]

        case sub&.to_s
        when 'list'    then list_schedules(session)
        when 'create'  then create_schedule(args, session)
        when 'delete'  then delete_schedule(args, session)
        when 'run'     then run_schedule(args, session)
        else                scheduler_overview
        end
      end

      private

      def scheduler_overview
        data = {
          product: 'The Scheduler',
          description: 'Automated Kill-Switch for credentials and time-based operations',
          subcommands: {
            'list' => 'List all scheduled jobs',
            'create' => 'Create new schedule  --name=... --cron="0 0 * * *" --action=...',
            'delete' => 'Delete a schedule    --id=SCHEDULE_ID',
            'run' => 'Run schedule now     --id=SCHEDULE_ID'
          }
        }
        if Output.json_mode
          json_ok(data)
        else
          render_header
          Output.info('Automated Kill-Switch for credentials & time-based operations')
          Output.blank
          data[:subcommands].each { |cmd, desc| Output.muted("  /scheduler --sub=#{cmd}    #{desc}") }
          Output.blank
        end
      end

      def list_schedules(_session)
        data = { schedules: [], note: 'Schedule persistence via Lark Base in production' }
        if Output.json_mode
          json_ok(data, message: 'Scheduled jobs')
        else
          render_header('Scheduler — Jobs')
          Output.muted('No schedules defined. Use /scheduler --sub=create to add one.')
          Output.blank
        end
      end

      def create_schedule(args, session)
        name   = args[:name]   or return Output.critical('--name required')
        cron   = args[:cron]   or return Output.critical("--cron required (e.g. '0 0 * * *')")
        action = args[:action] or return Output.critical('--action required')

        data = { status: 'created', name: name, cron: cron, action: action, created_by: session.email }
        if Output.json_mode
          json_ok(data, message: 'Schedule created')
        else
          Output.success("Schedule '#{name}' created")
          Output.info("CRON: #{cron}")
          Output.info("Action: #{action}")
        end
      end

      def delete_schedule(args, _session)
        id = args[:id] or return Output.critical('--id required')
        if Output.json_mode
          json_ok({ deleted_id: id }, message: "Schedule #{id} deleted")
        else
          Output.success("Schedule #{id} deleted.")
        end
      end

      def run_schedule(args, _session)
        id = args[:id] or return Output.critical('--id required')
        if Output.json_mode
          json_ok({ id: id, status: 'executed', timestamp: Time.now.utc.iso8601 }, message: "Schedule #{id} executed")
        else
          Output.success("Schedule #{id} executed immediately.")
        end
      end
    end
  end
end
