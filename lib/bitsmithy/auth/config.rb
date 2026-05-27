# frozen_string_literal: true

module Bitsmithy
  module Auth
    class Config
      JWT_ISSUER = "bitsmithy-auth"
      JWT_ALGORITHM = "HS256"
      DEFAULT_SESSION_DURATION = 86_400 # 24h per ADR-0001

      attr_accessor :signing_key, :otp_adapter, :session_duration,
                    :twilio_account_sid, :twilio_auth_token, :twilio_verify_service_sid

      def initialize
        @session_duration = DEFAULT_SESSION_DURATION
      end

      def validate!
        required = %i[twilio_account_sid twilio_auth_token twilio_verify_service_sid signing_key]
        missing = required.select { |k| public_send(k).nil? }
        raise ConfigurationError, "missing required config: #{missing}" if missing.any?
      end
    end
  end
end
