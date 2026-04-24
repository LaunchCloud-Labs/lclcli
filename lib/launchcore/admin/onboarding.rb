module LaunchCore
  module Admin
    class Onboarding
      def self.run(args, session)
        db_path = File.expand_path('../../../../lcl-employee/data/employee_portal.db', __dir__)
        unless File.exist?(db_path)
          Output.warning("Employee portal DB not found at #{db_path}")
          return
        end
        
        db = SQLite3::Database.new(db_path)
        db.results_as_hash = true
        
        if args[:approve]
          doc_id = args[:approve].to_i
          doc = db.get_first_row("SELECT * FROM onboarding_docs WHERE id = ?", [doc_id])
          unless doc
            Output.critical("Document ##{doc_id} not found.")
            return
          end
          
          db.execute("UPDATE onboarding_docs SET status = 'approved' WHERE id = ?", [doc_id])
          Output.success("Document ##{doc_id} approved.")
          
          # Check if all 6 required documents are approved
          user_id = doc['user_id']
          approved_docs = db.get_first_value("SELECT COUNT(*) FROM onboarding_docs WHERE user_id = ? AND status = 'approved'", [user_id])
          
          if approved_docs >= 6
            # Mark payable in lcl-payroll
            # We need the user's email.
            # However, profiles might not have email if not set, but users table in launchcore.db has it.
            # Let's try profiles first.
            user_email = db.get_first_value("SELECT email FROM profiles WHERE user_id = ?", [user_id])
            unless user_email
              # fallback to master launchcore db
              lc_db = Database::Models.db
              user_email = lc_db[:users].where(id: user_id).first&.fetch(:email)
            end
            
            if user_email
              Output.info("All 6 documents approved for #{user_email}. Marking as payable...")
              system("lcl-payroll /mark-payable LCL #{user_email} --auth-token=#{session.token}")
            else
              Output.warning("Could not find email for user_id #{user_id}")
            end
          end
        elsif args[:reject]
          doc_id = args[:reject].to_i
          db.execute("UPDATE onboarding_docs SET status = 'rejected' WHERE id = ?", [doc_id])
          Output.success("Document ##{doc_id} rejected.")
        else
          # List pending
          pending = db.execute("SELECT * FROM onboarding_docs WHERE status = 'pending'")
          if pending.empty?
            Output.success("No pending onboarding documents.")
          else
            Output.header("Pending Onboarding Documents")
            pending.each do |row|
              puts "  ID: #{row['id']} | User ID: #{row['user_id']} | Type: #{row['doc_type']} | File: #{row['file_path']}"
            end
            Output.blank
            Output.info("To approve: /admin --onboarding --approve=ID")
            Output.info("To reject:  /admin --onboarding --reject=ID")
          end
        end
      end
    end
  end
end
