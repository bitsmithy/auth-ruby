# frozen_string_literal: true

require_relative "auth/version"
require_relative "auth/config"
require_relative "auth/errors"
require_relative "auth/result"
require_relative "auth/token"
require_relative "auth/identity"
require_relative "auth/phone"
require_relative "auth/rate_limiter"
require_relative "auth/otp/test_adapter"
require_relative "auth/otp/twilio_adapter"
require_relative "auth/stores/memory_store"

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
        normalized = normalize_phone(phone)
        rate_limiter.check!("send_code:#{normalized}")
        config.otp_adapter.send_code(normalized)
      rescue RateLimited
        Result.failure(error: :rate_limited, phone: phone)
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
        unless defined?(Rails) && (Rails.env.test? || Rails.env.development?)
          raise ConfigurationError,
                "#{self}.#{__method__} is only available in Rails test or development environments."
        end

        config.otp_adapter = OTP::TestAdapter.new(config)
      end

      def reset_config!
        @config = nil
        @rate_limiter = nil
      end

      private

      def rate_limiter
        @rate_limiter ||= RateLimiter.new(
          store: config.rate_limit_store ||= Stores::MemoryStore.new,
          max_attempts: config.rate_limit[:per_phone],
          window: config.rate_limit[:window]
        )
      end
    end
  end
end
