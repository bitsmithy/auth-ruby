# frozen_string_literal: true

require "test_helper"

module Bitsmithy
  class TestAuth < Minitest::Test
    include ConfigHelper

    def test_that_it_has_a_version_number
      refute_nil ::Bitsmithy::Auth::VERSION
    end

    def test_send_code_returns_a_success_result_in_test_mode
      configure_for_tests

      result = Bitsmithy::Auth.send_code("+12127363100")

      assert_predicate result, :success?
    end

    def test_verify_code_in_test_mode_issues_a_token_that_decodes_to_the_phone
      configure_for_tests

      result = Bitsmithy::Auth.verify_code("+12127363100", "000000")
      identity = Bitsmithy::Auth.decode_token(result.token)

      assert_equal "+12127363100", identity.phone
    end

    def test_normalize_phone_returns_e164_for_us_number_with_country
      result = Bitsmithy::Auth.normalize_phone("(212) 736-3100", country: "US")

      assert_equal "+12127363100", result
    end

    def test_redact_phone_masks_the_middle_digits_of_an_e164_number
      assert_equal "+1******3100", Bitsmithy::Auth.redact_phone("+12127363100")
    end

    def test_token_expires_session_duration_seconds_after_issued_at
      configure_for_tests

      result = Bitsmithy::Auth.verify_code("+12127363100", "000000")
      identity = Bitsmithy::Auth.decode_token(result.token)

      assert_equal Bitsmithy::Auth::Config::DEFAULT_SESSION_DURATION,
                   (identity.expires_at - identity.issued_at).to_i
    end
  end
end
