# frozen_string_literal: true

require "bitsmithy/auth/result"
require "bitsmithy/auth/token"

module Bitsmithy
  module Auth
    module OTP
      class TestAdapter
        def initialize(config)
          @config = config
        end

        MAGIC_TEST_CODE = "000000"

        def send_code(phone)
          Result.success(phone: phone)
        end

        def verify_code(phone, code)
          if code == MAGIC_TEST_CODE
            Result.success(token: Token.encode(phone: phone, config: @config), phone: phone)
          else
            Result.failure(error: :invalid_code, phone: phone)
          end
        end
      end
    end
  end
end
