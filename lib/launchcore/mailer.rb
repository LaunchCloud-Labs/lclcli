# frozen_string_literal: true

require 'mail'

module LaunchCore
  class Mailer
    Mail.defaults do
      delivery_method :sendmail
    end

    SENDER = "#{Config::COMPANY_NAME} <#{Config::SENDER_EMAIL}>".freeze

    def self.welcome(email:, first_name:)
      deliver!(
        to: email,
        subject: "Welcome to LaunchCore Command, #{first_name}!",
        body: welcome_body(first_name)
      )
    rescue StandardError => e
      Output.muted("Mail delivery skipped: #{e.message}")
    end

    def self.invite(to:, code:, role:)
      return unless to

      deliver!(
        to: to,
        subject: 'You have been invited to LaunchCore Command',
        body: invite_body(code, role)
      )
    rescue StandardError => e
      Output.muted("Mail delivery skipped: #{e.message}")
    end

    def self.auth_level_upgrade(email:, first_name:, new_level:)
      deliver!(
        to: email,
        subject: "Auth Level Upgraded to L#{new_level} — LaunchCore Command",
        body: level_upgrade_body(first_name, new_level)
      )
    rescue StandardError => e
      Output.muted("Mail delivery skipped: #{e.message}")
    end

    def self.deliver!(to:, subject:, body:)
      Mail.deliver do
        from    SENDER
        to      to
        subject subject
        body    body
      end
    end

    def self.welcome_body(first_name)
      <<~BODY
        LaunchCore Command — #{Config::DOMAIN}
        #{'═' * 50}

        Hello #{first_name},

        Welcome to LaunchCore Command — your unified platform for
        voice, tunnel, neobanking, and beyond.

        Your account has been created and is now active.

        NEXT STEPS:
        ──────────
        1. Enable 2FA:   lc /settings/2fa
        2. Complete KYC: lc /settings/kyc
        3. Explore:      lc /help

        Auth Levels:
          L1 — Password Verified      (Current)
          L2 — 2FA Enabled
          L3 — KYC / ID Verified
          L4 — 30-Day Active Account

        Questions? #{Config::DOMAIN}

        — The LaunchCloud Labs Team
      BODY
    end

    def self.invite_body(code, role)
      <<~BODY
        LaunchCore Command — #{Config::DOMAIN}
        #{'═' * 50}

        You have been invited to join LaunchCore Command
        as a #{Config::USER_CLASSES[role] || role}.

        YOUR INVITE CODE: #{code}

        To accept:
          lc /auth/signup

        When prompted, enter your invite code.
        This code expires in 7 days.

        — The LaunchCloud Labs Team
      BODY
    end

    def self.level_upgrade_body(first_name, level)
      <<~BODY
        LaunchCore Command — #{Config::DOMAIN}
        #{'═' * 50}

        Hello #{first_name},

        Your account has been upgraded to Auth Level #{level}:
        #{Config::AUTH_LEVELS[level]}

        New features are now unlocked on your dashboard.

        — The LaunchCloud Labs Team
      BODY
    end
  end
end
