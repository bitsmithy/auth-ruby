# frozen_string_literal: true

require "test_helper"

module Bitsmithy
  module Auth
    class TestController < Minitest::Test
      include ConfigHelper

      # Minimal Rails-controller stand-in. Exposes a session Hash and
      # mixes in the concern under test.
      class FakeController
        include Bitsmithy::Auth::Controller

        attr_reader :session

        def initialize(session = {})
          @session = session
        end
      end

      def test_current_phone_returns_phone_from_valid_token_in_session
        configure_for_tests
        token = Bitsmithy::Auth.verify_code("+12127363100", "000000").token
        controller = FakeController.new(bitsmithy_auth_token: token)

        assert_equal "+12127363100", controller.current_phone
      end

      def test_current_phone_returns_nil_when_session_is_empty
        configure_for_tests
        controller = FakeController.new({})

        assert_nil controller.current_phone
      end

      def test_authenticated_returns_false_when_session_is_empty
        configure_for_tests
        controller = FakeController.new({})

        refute_predicate controller, :authenticated?
      end

      def test_current_phone_returns_nil_for_invalid_token_in_session
        configure_for_tests
        controller = FakeController.new(bitsmithy_auth_token: "garbage.jwt.token")

        assert_nil controller.current_phone
      end

      def test_sign_in_writes_token_to_session_and_invalidates_memo
        configure_for_tests
        controller = FakeController.new({})
        controller.current_phone # memoise the (nil) identity
        token = Bitsmithy::Auth.verify_code("+12127363100", "000000").token

        controller.sign_in(token: token)

        assert_equal "+12127363100", controller.current_phone
      end

      def test_sign_out_clears_session_and_invalidates_memo
        configure_for_tests
        token = Bitsmithy::Auth.verify_code("+12127363100", "000000").token
        controller = FakeController.new(bitsmithy_auth_token: token)
        controller.current_phone # memoise the identity

        controller.sign_out

        assert_nil controller.current_phone
      end

      def test_concern_defines_require_authentication_method
        assert_respond_to FakeController.new, :require_authentication!
      end
    end
  end
end
