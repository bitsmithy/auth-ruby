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
            entry = @data[key]

            if entry.nil? || entry[:expires_at] <= now
              @data[key] = { count: 1, expires_at: now + window_seconds }
            else
              entry[:count] += 1
            end

            @data[key][:count]
          end
        end
      end
    end
  end
end
