# frozen_string_literal: true

require_relative "auth/version"
require_relative "auth/config"
require_relative "auth/errors"
require_relative "auth/result"
require_relative "auth/token"
require_relative "auth/identity"
require_relative "auth/phone"
require_relative "auth/otp/test_adapter"

module Bitsmithy
  module Auth
    class Error < StandardError; end

    class << self
      def config
        @config ||= Config.new
      end

      def configure
        yield config
        config
      end

      def send_code(phone)
        config.otp_adapter.send_code(normalize_phone(phone))
      rescue InvalidPhoneNumber
        Result.failure(error: :invalid_phone_number, phone: phone)
      end

      def verify_code(phone, code)
        config.otp_adapter.verify_code(phone, code)
      end

      def decode_token(token)
        Token.decode(token, config: @config)
      end

      def normalize_phone(input, country: nil)
        Phone.normalized(input, country: country)
      end

      def redact_phone(phone)
        Phone.redact(phone)
      end

      # Test Methods

      def test_mode!
        config.otp_adapter = OTP::TestAdapter.new(config)
      end

      def reset_config!
        @config = nil
      end
    end
  end
end
