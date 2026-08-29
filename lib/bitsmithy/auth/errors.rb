# frozen_string_literal: true

module Bitsmithy
  module Auth
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class ExpiredEnvelope < Error; end
    class InvalidEmail < Error; end
    class InvalidEnvelope < Error; end
    class ProviderUnavailable < Error; end
  end
end
