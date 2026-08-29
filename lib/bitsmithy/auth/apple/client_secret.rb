# frozen_string_literal: true

require "jwt"
require "openssl"

module Bitsmithy
  module Auth
    module Apple
      module ClientSecret
        LIFETIME = 30 * 24 * 60 * 60

        module_function

        def issue(config)
          key = OpenSSL::PKey.read(config.apple_private_key)
          JWT.encode(claims(config), key, "ES256", kid: config.apple_key_id)
        rescue OpenSSL::PKey::PKeyError, TypeError
          raise ConfigurationError, "apple_private_key must be a valid EC private key"
        end

        def claims(config)
          issued_at = config.clock.call.to_i
          {
            iss: config.apple_team_id,
            iat: issued_at,
            exp: issued_at + LIFETIME,
            aud: ISSUER,
            sub: config.apple_client_id
          }
        end
        private_class_method :claims
      end
    end
  end
end
