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

        def send_code(phone)
          Result.success(phone: phone)
        end

        def verify_code(phone, code)
          if code == "000000"
            Token.encode(phone: phone, config: @config).then do |token|
              Result.success(token: token, phone: phone)
            end
          else
            Result.failure(error: :invalid_code, phone: phone)
          end
        end
      end
    end
  end
end
