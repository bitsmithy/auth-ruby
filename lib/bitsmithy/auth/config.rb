# frozen_string_literal: true

require_relative "errors"
require_relative "stores/memory_store"
require_relative "stores/rails_cache_store"

module Bitsmithy
  module Auth
    class Config
      JWT_ISSUER = "bitsmithy-auth"
      JWT_ALGORITHM = "HS256"
      DEFAULT_SESSION_DURATION = 86_400 # 24h per ADR-0001
      DEFAULT_RATE_LIMIT = { per_phone: 5, window: 3_600 }.freeze
      CACHE_MISSING_WARNING = "[bitsmithy-auth] Rails.cache is nil — configure config.cache_store " \
                              "for cross-worker rate limiting. Falling back to MemoryStore."

      attr_accessor :signing_key, :otp_adapter, :session_duration, :rate_limit,
                    :twilio_account_sid, :twilio_auth_token, :twilio_verify_service_sid,
                    :sign_in_path,
                    :after_sign_in_path, :after_sign_out_path,
                    :on_verified
      attr_writer :rate_limit_store

      def initialize
        @session_duration = DEFAULT_SESSION_DURATION
        @rate_limit = DEFAULT_RATE_LIMIT.dup
        @after_sign_in_path = "/"
        @after_sign_out_path = "/"
      end

      def rate_limit_store
        @rate_limit_store ||= if defined?(Rails) && Rails.respond_to?(:cache)
                                if Rails.cache
                                  Stores::RailsCacheStore.new(Rails.cache)
                                else
                                  warn CACHE_MISSING_WARNING
                                  Stores::MemoryStore.new
                                end
                              else
                                Stores::MemoryStore.new
                              end
      end

      def validate!
        required = %i[twilio_account_sid twilio_auth_token twilio_verify_service_sid signing_key]
        missing = required.select { |k| public_send(k).nil? }
        raise ConfigurationError, "missing required config: #{missing}" if missing.any?
      end
    end
  end
end
