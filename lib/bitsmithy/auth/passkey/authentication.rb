# frozen_string_literal: true

module Bitsmithy
  module Auth
    module Passkey
      class Authentication
        def initialize(config)
          @config = config
        end

        def start(return_to:)
          options = config.passkey_relying_party.options_for_authentication(
            allow: [],
            user_verification: "required"
          )
          state = Envelope.seal(ceremony_state(options.challenge, return_to), key: config.envelope_key)
          Ceremony.new(options: JSON.parse(JSON.generate(options.as_json)), state: state)
        end

        def finish(credential:, state:, stored_credential:)
          ceremony = Envelope.open(state, key: config.envelope_key)
          validate_ceremony!(ceremony, config.clock.call)
          raise InvalidEnvelope unless credential["id"] == stored_credential.credential_id

          verified = verify(credential, ceremony, stored_credential)
          successful_result(verified, stored_credential, ceremony)
        rescue InvalidEnvelope, KeyError, TypeError, WebAuthn::Error
          Result.failure(error: :invalid_passkey_authentication)
        end

        private

        attr_reader :config

        def ceremony_state(challenge, return_to)
          now = config.clock.call
          {
            "purpose" => AUTHENTICATION_PURPOSE,
            "challenge" => challenge,
            "return_to" => validated_return_to(return_to),
            "issued_at" => now.to_i,
            "expires_at" => (now + CEREMONY_TTL).to_i
          }
        end

        def evidence(verified, stored)
          AuthenticationEvidence.passkey(
            credential_id: verified.id,
            user_handle: stored.user_handle,
            signature_count: verified.sign_count,
            authenticated_at: config.clock.call
          )
        end

        def successful_result(verified, stored, ceremony)
          Result.success(
            evidence: evidence(verified, stored),
            metadata: { return_to: ceremony.fetch("return_to") }
          )
        end

        def validate_ceremony!(ceremony, now)
          raise InvalidEnvelope unless ceremony["purpose"] == AUTHENTICATION_PURPOSE
          raise InvalidEnvelope if ceremony.fetch("expires_at") <= now.to_i
        end

        def validated_return_to(input)
          value = input.to_s
          return value if value.start_with?("/") && !value.start_with?("//")

          raise ConfigurationError, "return_to must be an application-relative path"
        end

        def verify(credential, ceremony, stored)
          config.passkey_relying_party.verify_authentication(
            credential,
            ceremony.fetch("challenge"),
            public_key: stored.public_key,
            sign_count: stored.signature_count,
            user_presence: true,
            user_verification: true
          )
        end
      end
    end
  end
end
