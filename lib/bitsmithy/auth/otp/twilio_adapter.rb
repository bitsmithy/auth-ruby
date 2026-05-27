# frozen_string_literal: true

require "twilio-ruby"
require "bitsmithy/auth/result"
require "bitsmithy/auth/token"

module Bitsmithy
  module Auth
    module OTP
      class TwilioAdapter
        ERROR_CODE_MAP = {
          60_200 => :invalid_phone_number,
          60_202 => :max_check_attempts,
          60_203 => :max_send_attempts
        }.freeze

        def initialize(config)
          @config = config
        end

        def send_code(phone)
          verify_service.verifications.create(to: phone, channel: "sms")
          Result.success(phone: phone, channel: :sms)
        rescue Twilio::REST::RestError => e
          Result.failure(error: map_error(e), phone: phone)
        end

        def verify_code(phone, code)
          check = verify_service.verification_checks.create(to: phone, code: code)

          if check.status == "approved"
            Result.success(token: Token.encode(phone: phone, config: @config), phone: phone)
          else
            Result.failure(error: :invalid_code, phone: phone)
          end
        rescue Twilio::REST::RestError => e
          Result.failure(error: map_error(e), phone: phone)
        end

        private

        def verify_service
          twilio_client.verify.v2.services(@config.twilio_verify_service_sid)
        end

        def twilio_client
          @twilio_client ||= Twilio::REST::Client.new(
            @config.twilio_account_sid,
            @config.twilio_auth_token
          )
        end

        def map_error(error)
          ERROR_CODE_MAP[error.code] || map_status_code(error.status_code) || :twilio_error
        end

        def map_status_code(code)
          case code
          when 401 then :twilio_authentication_error
          when 429 then :twilio_rate_limited
          when 500..529 then :twilio_service_unavailable
          end
        end
      end
    end
  end
end
