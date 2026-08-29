# frozen_string_literal: true

module Bitsmithy
  module Auth
    module Passkey
      class Registration
        def initialize(config)
          @config = config
        end

        def start(user_handle:, user_name:, exclude_credential_ids:)
          options = registration_options(user_handle, user_name, exclude_credential_ids)
          state = Envelope.seal(ceremony_state(options.challenge, user_handle), key: config.envelope_key)
          Ceremony.new(options: JSON.parse(JSON.generate(options.as_json)), state: state)
        end

        def finish(credential:, state:, user_handle:)
          ceremony = Envelope.open(state, key: config.envelope_key)
          validate_ceremony!(ceremony, user_handle, config.clock.call)
          verified = verify(credential, ceremony)
          Result.success(metadata: { credential: credential_values(verified) })
        rescue InvalidEnvelope, KeyError, TypeError, WebAuthn::Error
          Result.failure(error: :invalid_passkey_registration)
        end

        private

        attr_reader :config

        def ceremony_state(challenge, user_handle)
          now = config.clock.call
          {
            "purpose" => REGISTRATION_PURPOSE,
            "challenge" => challenge,
            "user_handle" => user_handle,
            "issued_at" => now.to_i,
            "expires_at" => (now + CEREMONY_TTL).to_i
          }
        end

        def credential_values(verified)
          Credential.new(
            credential_id: verified.id,
            public_key: verified.public_key,
            signature_count: verified.sign_count
          )
        end

        def registration_options(user_handle, user_name, excluded)
          config.passkey_relying_party.options_for_registration(
            user: { id: user_handle, name: user_name },
            exclude: excluded,
            authenticator_selection: { resident_key: "required", user_verification: "required" },
            attestation: "none"
          )
        end

        def validate_ceremony!(ceremony, user_handle, now)
          raise InvalidEnvelope unless ceremony["purpose"] == REGISTRATION_PURPOSE
          raise InvalidEnvelope unless ceremony["user_handle"] == user_handle
          raise InvalidEnvelope if ceremony.fetch("expires_at") <= now.to_i
        end

        def verify(credential, ceremony)
          config.passkey_relying_party.verify_registration(
            credential,
            ceremony.fetch("challenge"),
            user_presence: true,
            user_verification: true
          )
        end
      end
    end
  end
end
