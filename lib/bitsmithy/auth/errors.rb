# frozen_string_literal: true

module Bitsmithy
  module Auth
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class InvalidPhoneNumber < Error; end
    class InvalidToken < Error; end
    class RateLimited < Error; end
  end
end
