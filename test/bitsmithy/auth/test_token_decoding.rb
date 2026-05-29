# frozen_string_literal: true

require "test_helper"

module Bitsmithy
  module Auth
    class TestTokenDecoding < Minitest::Test
      include ConfigHelper

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
    end
  end
end
