# frozen_string_literal: true

require "test_helper"

module Bitsmithy
  module Auth
    module OTP
      class TestTwilioAdapter < Minitest::Test
        include ConfigHelper

        def setup
          super
          Bitsmithy::Auth.configure do |c|
            c.signing_key = "x" * 64
            c.twilio_account_sid = "ACtest"
            c.twilio_auth_token = "secret"
            c.twilio_verify_service_sid = "VAtest"
          end
        end

        def test_send_code_returns_success_result_when_twilio_accepts
          adapter = TwilioAdapter.new(Bitsmithy::Auth.config)
          verifications = mock
          verifications.expects(:create).with(to: "+12127363100", channel: "sms").returns(stub(status: "pending"))
          adapter.stubs(:verify_service).returns(stub(verifications: verifications))

          result = adapter.send_code("+12127363100")

          assert_predicate result, :success?
        end

        def test_verify_code_returns_success_with_decodable_token_when_check_is_approved
          adapter = TwilioAdapter.new(Bitsmithy::Auth.config)
          checks = mock
          checks.expects(:create).with(to: "+12127363100", code: "123456").returns(stub(status: "approved"))
          adapter.stubs(:verify_service).returns(stub(verification_checks: checks))

          result = adapter.verify_code("+12127363100", "123456")
          identity = Bitsmithy::Auth.decode_token(result.token)

          assert_equal "+12127363100", identity.phone
        end

        def test_send_code_maps_twilio_error_60200_to_invalid_phone_number
          adapter = TwilioAdapter.new(Bitsmithy::Auth.config)
          verifications = mock
          verifications.expects(:create).raises(twilio_rest_error(code: 60_200))
          adapter.stubs(:verify_service).returns(stub(verifications: verifications))

          result = adapter.send_code("+12127363100")

          assert_equal :invalid_phone_number, result.error
        end

        def test_verify_code_maps_twilio_error_60202_to_max_check_attempts
          adapter = TwilioAdapter.new(Bitsmithy::Auth.config)
          checks = mock
          checks.expects(:create).raises(twilio_rest_error(code: 60_202))
          adapter.stubs(:verify_service).returns(stub(verification_checks: checks))

          result = adapter.verify_code("+12127363100", "123456")

          assert_equal :max_check_attempts, result.error
        end

        def test_send_code_maps_twilio_error_60203_to_max_send_attempts
          adapter = TwilioAdapter.new(Bitsmithy::Auth.config)
          verifications = mock
          verifications.expects(:create).raises(twilio_rest_error(code: 60_203))
          adapter.stubs(:verify_service).returns(stub(verifications: verifications))

          result = adapter.send_code("+12127363100")

          assert_equal :max_send_attempts, result.error
        end

        def test_send_code_maps_twilio_401_to_authentication_error
          adapter = TwilioAdapter.new(Bitsmithy::Auth.config)
          verifications = mock
          verifications.expects(:create).raises(twilio_rest_error(code: 20_003, status: 401))
          adapter.stubs(:verify_service).returns(stub(verifications: verifications))

          result = adapter.send_code("+12127363100")

          assert_equal :twilio_authentication_error, result.error
        end

        def test_send_code_maps_twilio_429_to_rate_limited
          adapter = TwilioAdapter.new(Bitsmithy::Auth.config)
          verifications = mock
          verifications.expects(:create).raises(twilio_rest_error(code: 20_429, status: 429))
          adapter.stubs(:verify_service).returns(stub(verifications: verifications))

          result = adapter.send_code("+12127363100")

          assert_equal :twilio_rate_limited, result.error
        end

        def test_send_code_maps_twilio_5xx_to_service_unavailable
          adapter = TwilioAdapter.new(Bitsmithy::Auth.config)
          verifications = mock
          verifications.expects(:create).raises(twilio_rest_error(code: 20_500, status: 503))
          adapter.stubs(:verify_service).returns(stub(verifications: verifications))

          result = adapter.send_code("+12127363100")

          assert_equal :twilio_service_unavailable, result.error
        end

        def test_send_code_falls_back_to_twilio_error_for_unmapped_code
          adapter = TwilioAdapter.new(Bitsmithy::Auth.config)
          verifications = mock
          verifications.expects(:create).raises(twilio_rest_error(code: 99_999, status: 418))
          adapter.stubs(:verify_service).returns(stub(verifications: verifications))

          result = adapter.send_code("+12127363100")

          assert_equal :twilio_error, result.error
        end

        private

        def twilio_rest_error(code:, status: 400)
          response = stub(status_code: status, body: { "code" => code, "message" => "test" })
          Twilio::REST::RestError.new("test", response)
        end
      end
    end
  end
end
