# frozen_string_literal: true

require "test_helper"

module Bitsmithy
  module Auth
    class TestRateLimiting < Minitest::Test
      include ConfigHelper

      def test_send_code_returns_rate_limited_failure_after_max_attempts_per_phone
        configure_for_tests
        phone = "+12127363100"

        5.times { Bitsmithy::Auth.send_code(phone) }
        result = Bitsmithy::Auth.send_code(phone)

        assert_equal :rate_limited, result.error
      end

      def test_rate_limit_is_isolated_per_phone
        configure_for_tests
        5.times { Bitsmithy::Auth.send_code("+12127363100") }

        result = Bitsmithy::Auth.send_code("+14157361200")

        assert_predicate result, :success?
      end

      def test_rate_limit_resets_after_window_expires
        configure_for_tests
        phone = "+12127363100"
        5.times { Bitsmithy::Auth.send_code(phone) }
        future = Time.now + Bitsmithy::Auth::Config::DEFAULT_RATE_LIMIT[:window] + 1
        Time.stubs(:now).returns(future)

        result = Bitsmithy::Auth.send_code(phone)

        assert_predicate result, :success?
      end

      def test_memory_store_is_mutex_protected_under_concurrent_load
        store = Bitsmithy::Auth::Stores::MemoryStore.new
        thread_count = 10
        per_thread = 100

        threads = Array.new(thread_count) do
          Thread.new { per_thread.times { store.increment("key", 3_600) } }
        end
        threads.each(&:join)
        final_count_after_one_more = store.increment("key", 3_600)

        assert_equal (thread_count * per_thread) + 1, final_count_after_one_more
      end

      def test_custom_store_is_used_when_set_on_config
        custom_store = mock
        custom_store.expects(:increment).at_least_once.returns(1)
        Bitsmithy::Auth.configure do |c|
          c.signing_key = "x" * 64
          c.rate_limit_store = custom_store
        end
        Bitsmithy::Auth.test_mode!

        Bitsmithy::Auth.send_code("+12127363100")
      end

      def test_config_rate_limit_default_is_five_per_phone_per_hour
        config = Bitsmithy::Auth::Config.new

        assert_equal({ per_phone: 5, window: 3_600 }, config.rate_limit)
      end
    end
  end
end
