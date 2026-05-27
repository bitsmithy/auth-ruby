# frozen_string_literal: true

require "jwt"

module Bitsmithy
  module Auth
    module Token
      def self.encode(phone:, config:)
        iat = Time.now.to_i
        payload = { sub: phone, iat: iat, exp: iat + config.session_duration, iss: Config::JWT_ISSUER }
        JWT.encode(payload, config.signing_key, Config::JWT_ALGORITHM)
      end

      def self.decode(token, config:)
        payload, _header = JWT.decode(token, config.signing_key, true,
                                      algorithm: Config::JWT_ALGORITHM,
                                      iss: Config::JWT_ISSUER,
                                      verify_iss: true)
        Identity.new(
          phone: payload["sub"],
          issued_at: Time.at(payload["iat"]),
          expires_at: Time.at(payload["exp"])
        )
      end
    end
  end
end
