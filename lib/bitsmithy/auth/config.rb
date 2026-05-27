# frozen_string_literal: true

module Bitsmithy
  module Auth
    class Config
      JWT_ISSUER = "bitsmithy-auth"
      JWT_ALGORITHM = "HS256"
      DEFAULT_SESSION_DURATION = 86_400 # 24h per ADR-0001

      attr_accessor :signing_key, :otp_adapter, :session_duration

      def initialize
        @session_duration = DEFAULT_SESSION_DURATION
      end
    end
  end
end
