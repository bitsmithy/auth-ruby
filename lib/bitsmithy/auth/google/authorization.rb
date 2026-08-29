# frozen_string_literal: true

require "base64"
require "digest"
require "securerandom"
require "uri"

module Bitsmithy
  module Auth
    module Google
      class Authorization
        def initialize(config)
          @config = config
        end

        def start(redirect_uri:, return_to:)
          verifier = SecureRandom.urlsafe_base64(32, padding: false)
          nonce = SecureRandom.urlsafe_base64(24, padding: false)
          state = Envelope.seal(state_payload(redirect_uri, return_to, verifier, nonce), key: config.envelope_key)
          AuthorizationRequest.new(url: authorization_url(redirect_uri, verifier, nonce, state))
        end

        private

        attr_reader :config

        def authorization_url(redirect_uri, verifier, nonce, state)
          query = URI.encode_www_form(authorization_parameters(redirect_uri, verifier, nonce, state))
          "#{AUTHORIZATION_ENDPOINT}?#{query}"
        end

        def authorization_parameters(redirect_uri, verifier, nonce, state)
          {
            client_id: config.google_client_id,
            redirect_uri: validated_redirect_uri(redirect_uri),
            response_type: "code",
            scope: "openid email",
            state: state,
            nonce: nonce,
            code_challenge: code_challenge(verifier),
            code_challenge_method: "S256"
          }
        end

        def code_challenge(verifier)
          digest = Digest::SHA256.digest(verifier)
          Base64.urlsafe_encode64(digest, padding: false)
        end

        def state_payload(redirect_uri, return_to, verifier, nonce)
          now = config.clock.call
          {
            "purpose" => PURPOSE,
            "redirect_uri" => validated_redirect_uri(redirect_uri),
            "return_to" => validated_return_to(return_to),
            "verifier" => verifier,
            "nonce" => nonce,
            "issued_at" => now.to_i,
            "expires_at" => (now + CEREMONY_TTL).to_i
          }
        end

        def validated_redirect_uri(input)
          uri = URI.parse(input.to_s)
          return uri.to_s if uri.is_a?(URI::HTTPS) && uri.host

          raise ConfigurationError, "Google redirect_uri must be an absolute HTTPS URL"
        rescue URI::InvalidURIError
          raise ConfigurationError, "Google redirect_uri must be an absolute HTTPS URL"
        end

        def validated_return_to(input)
          value = input.to_s
          return value if value.start_with?("/") && !value.start_with?("//")

          raise ConfigurationError, "return_to must be an application-relative path"
        end
      end
    end
  end
end
