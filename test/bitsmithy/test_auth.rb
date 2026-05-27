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

    def test_verify_code_returns_invalid_code_failure_for_wrong_code
      configure_for_tests

      result = Bitsmithy::Auth.verify_code("+12127363100", "999999")

      assert_equal :invalid_code, result.error
    end

    def test_send_code_returns_invalid_phone_number_failure_for_unparseable_input
      configure_for_tests

      result = Bitsmithy::Auth.send_code("not a phone")

      assert_equal :invalid_phone_number, result.error
    end

    def test_decode_token_raises_invalid_token_for_garbage_input
      configure_for_tests

      assert_raises(Bitsmithy::Auth::InvalidToken) do
        Bitsmithy::Auth.decode_token("this is not a jwt")
      end
    end

    def test_decode_token_raises_invalid_token_for_token_signed_with_other_key
      configure_for_tests
      result = Bitsmithy::Auth.verify_code("+12127363100", "000000")
      token = result.token

      Bitsmithy::Auth.config.signing_key = "a" * 64

      assert_raises(Bitsmithy::Auth::InvalidToken) do
        Bitsmithy::Auth.decode_token(token)
      end
    end

    def test_decode_token_raises_invalid_token_for_token_with_wrong_issuer
      configure_for_tests
      now = Time.now.to_i
      foreign_token = JWT.encode(
        { sub: "+12127363100", iat: now, exp: now + 86_400, iss: "some-other-issuer" },
        Bitsmithy::Auth.config.signing_key,
        "HS256"
      )

      assert_raises(Bitsmithy::Auth::InvalidToken) do
        Bitsmithy::Auth.decode_token(foreign_token)
      end
    end

    def test_decode_token_raises_invalid_token_for_expired_token
      configure_for_tests
      past = Time.now.to_i - 7_200
      expired_token = JWT.encode(
        { sub: "+12127363100", iat: past, exp: past + 60, iss: Bitsmithy::Auth::Config::JWT_ISSUER },
        Bitsmithy::Auth.config.signing_key,
        "HS256"
      )

      assert_raises(Bitsmithy::Auth::InvalidToken) do
        Bitsmithy::Auth.decode_token(expired_token)
      end
    end

    def test_config_validate_raises_configuration_error_when_required_field_missing
      config = Bitsmithy::Auth::Config.new

      assert_raises(Bitsmithy::Auth::ConfigurationError) do
        config.validate!
      end
    end

    def test_config_validate_passes_when_all_required_fields_set
      config = Bitsmithy::Auth::Config.new
      config.signing_key = "x" * 64
      config.twilio_account_sid = "ACtest"
      config.twilio_auth_token = "secret"
      config.twilio_verify_service_sid = "VAtest"

      assert_nil config.validate!
    end

    def test_invalid_phone_number_error_includes_raw_input_for_debuggability
      raw_input = "+15555551234"

      error = assert_raises(Bitsmithy::Auth::InvalidPhoneNumber) do
        Bitsmithy::Auth.normalize_phone(raw_input, country: "US")
      end

      assert_includes error.message, raw_input
    end
  end
end
