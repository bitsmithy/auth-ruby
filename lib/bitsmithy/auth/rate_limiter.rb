# frozen_string_literal: true

require_relative "errors"

module Bitsmithy
  module Auth
    class RateLimiter
      def initialize(store:, max_attempts:, window:)
        @store = store
        @max_attempts = max_attempts
        @window = window
      end

      def check!(key)
        raise RateLimited if @store.increment(key, @window) > @max_attempts
      end
    end
  end
end
