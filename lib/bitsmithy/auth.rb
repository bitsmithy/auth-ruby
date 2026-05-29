# frozen_string_literal: true

require_relative "auth/version"
require_relative "auth/errors"
require_relative "auth/config"
require_relative "auth/result"
require_relative "auth/token"
require_relative "auth/phone"
require_relative "auth/rate_limiter"
require_relative "auth/stores/memory_store"
require_relative "auth/otp/test_adapter"

require_relative "auth/controller" if defined?(ActionController)

module Bitsmithy
  module Auth
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
        Result.failure(error: :rate_limited, phone: normalized)
      rescue InvalidPhoneNumber
        Result.failure(error: :invalid_phone_number, phone: phone)
      end

      def verify_code(phone, code)
        normalized = normalize_phone(phone)
        config.otp_adapter.verify_code(normalized, code)
      rescue InvalidPhoneNumber
        Result.failure(error: :invalid_phone_number, phone: phone)
      end

      def decode_token(token)
        Token.decode(token, config: config)
      end

      def normalize_phone(input, country: nil)
        Phone.normalized(input, country: country)
      end

      def redact_phone(phone)
        Phone.redact(phone)
      end

      def test_mode!
        unless defined?(Rails) && (Rails.env.test? || Rails.env.development?)
          raise ConfigurationError,
                "#{self}.#{__method__} is only available in Rails test or development environments."
        end

        config.signing_key ||= "test-signing-key-not-for-production"
        config.otp_adapter = OTP::TestAdapter.new(config)
      end

      def reset_config!
        @config = nil
        @rate_limiter = nil
      end

      private

      def rate_limiter
        @rate_limiter ||= RateLimiter.new(
          store: config.rate_limit_store,
          max_attempts: config.rate_limit[:per_phone],
          window: config.rate_limit[:window]
        )
      end
    end
  end
end
