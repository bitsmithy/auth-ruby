# frozen_string_literal: true

module Bitsmithy
  module Auth
    module Stores
      class MemoryStore
        def initialize
          @data = {}
          @mutex = Mutex.new
        end

        def increment(key, window_seconds)
          @mutex.synchronize do
            now = Time.now.to_i
            @data.delete_if { |_k, v| v[:expires_at] <= now }

            @data[key] ||= { count: 0, expires_at: now + window_seconds }
            @data[key][:count] += 1
          end
        end
      end
    end
  end
end
