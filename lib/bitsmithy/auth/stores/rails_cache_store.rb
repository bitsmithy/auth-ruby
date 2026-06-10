# frozen_string_literal: true

module Bitsmithy
  module Auth
    module Stores
      # Wraps an ActiveSupport::Cache::Store (typically Rails.cache) so the
      # rate limiter works across worker processes when a distributed cache
      # (Redis, Memcached) is configured.
      #
      # Falls back gracefully: if Rails.cache is nil the caller should use
      # MemoryStore instead — see Config#rate_limit_store.
      class RailsCacheStore
        def initialize(cache)
          @cache = cache
        end

        # Increment the counter for +key+ and return the new value.
        # Expires the entry after +window_seconds+.
        def increment(key, window_seconds)
          @cache.increment(key, 1, expires_in: window_seconds)
        end
      end
    end
  end
end
