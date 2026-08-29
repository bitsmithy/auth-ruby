# frozen_string_literal: true

module Bitsmithy
  module Auth
    module Google
      AUTHORIZATION_ENDPOINT = "https://accounts.google.com/o/oauth2/v2/auth"
      CEREMONY_TTL = 600
      ISSUERS = ["https://accounts.google.com", "accounts.google.com"].freeze
      PURPOSE = "google_authentication"

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

require_relative "google/authorization"
require_relative "google/http_client"
require_relative "google/verification"
