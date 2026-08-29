# frozen_string_literal: true

require "json"
require "webauthn"

module Bitsmithy
  module Auth
    module Passkey
      AUTHENTICATION_PURPOSE = "passkey_authentication"
      CEREMONY_TTL = 300
      REGISTRATION_PURPOSE = "passkey_registration"
      Ceremony = Data.define(:options, :state)
      Credential = Data.define(:credential_id, :public_key, :signature_count)
      StoredCredential = Data.define(:credential_id, :public_key, :signature_count, :user_handle)

      module_function

      def finish_authentication(credential:, state:, stored_credential:, config:)
        Authentication.new(config).finish(
          credential: credential,
          state: state,
          stored_credential: stored_credential
        )
      end

      def finish_registration(credential:, state:, user_handle:, config:)
        Registration.new(config).finish(
          credential: credential,
          state: state,
          user_handle: user_handle
        )
      end

      def start_authentication(return_to:, config:)
        Authentication.new(config).start(return_to: return_to)
      end

      def start_registration(user_handle:, user_name:, exclude_credential_ids:, config:)
        Registration.new(config).start(
          user_handle: user_handle,
          user_name: user_name,
          exclude_credential_ids: exclude_credential_ids
        )
      end
    end
  end
end

require_relative "passkey/authentication"
require_relative "passkey/registration"
