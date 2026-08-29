# frozen_string_literal: true

module Bitsmithy
  module Auth
    module Apple
      AUTHORIZATION_ENDPOINT = "https://appleid.apple.com/auth/authorize"
      CEREMONY_TTL = 600
      ISSUER = "https://appleid.apple.com"
      PURPOSE = "apple_authentication"

      module_function

      def start(redirect_uri:, return_to:, config:)
        Authorization.new(config).start(redirect_uri: redirect_uri, return_to: return_to)
      end

      def finish(code:, state:, redirect_uri:, config:)
        Verification.new(config).finish(code: code, state: state, redirect_uri: redirect_uri)
      end
    end
  end
end

require_relative "apple/authorization"
require_relative "apple/client_secret"
require_relative "apple/http_client"
require_relative "apple/verification"
