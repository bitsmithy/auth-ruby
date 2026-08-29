# frozen_string_literal: true

require "jwt"

module Bitsmithy
  module Auth
    module Google
      class Verification
        def initialize(config)
          @config = config
        end

        def finish(code:, state:, redirect_uri:)
          ceremony = decoded_ceremony(state, redirect_uri)
          token_response = exchange_code(code, ceremony)
          claims = decoded_claims(token_response.fetch("id_token"))
          validate_claims!(claims, ceremony.fetch("nonce"), config.clock.call)
          successful_result(claims, ceremony)
        rescue ProviderUnavailable
          Result.failure(error: :google_unavailable)
        rescue InvalidEmail, InvalidEnvelope, JWT::DecodeError, KeyError, TypeError
          Result.failure(error: :invalid_google_authentication)
        end

        private

        attr_reader :config

        def decoded_ceremony(state, redirect_uri)
          ceremony = Envelope.open(state, key: config.envelope_key)
          raise InvalidEnvelope unless ceremony["purpose"] == PURPOSE
          raise InvalidEnvelope unless ceremony["redirect_uri"] == redirect_uri
          raise ExpiredEnvelope if ceremony.fetch("expires_at") <= config.clock.call.to_i

          ceremony
        end

        def decoded_claims(id_token)
          JWT.decode(id_token, nil, true, **decode_options).first
        end

        def decode_options
          {
            algorithms: ["RS256"],
            jwks: config.google_provider_client.jwks,
            iss: ISSUERS,
            verify_iss: true,
            aud: config.google_client_id,
            verify_aud: true,
            verify_expiration: false
          }
        end

        def evidence_from(claims)
          AuthenticationEvidence.federated(
            provider: :google,
            subject: claims.fetch("sub"),
            email: Email.normalize(claims.fetch("email")),
            authenticated_at: Time.at(claims.fetch("iat")).utc
          )
        end

        def exchange_code(code, ceremony)
          config.google_provider_client.exchange(
            code: code,
            redirect_uri: ceremony.fetch("redirect_uri"),
            code_verifier: ceremony.fetch("verifier"),
            client_id: config.google_client_id,
            client_secret: config.google_client_secret
          )
        end

        def successful_result(claims, ceremony)
          Result.success(
            evidence: evidence_from(claims),
            metadata: { return_to: ceremony.fetch("return_to") }
          )
        end

        def validate_claims!(claims, nonce, now)
          raise InvalidEnvelope unless claims["nonce"] == nonce
          raise InvalidEnvelope unless claims["email_verified"] == true
          raise InvalidEnvelope unless claims.fetch("exp") > now.to_i
          raise InvalidEnvelope unless claims.fetch("iat") <= now.to_i
        end
      end
    end
  end
end
