# frozen_string_literal: true

module Bitsmithy
  module Auth
    module PasskeyMethods
      def finish_passkey_authentication(credential:, state:, stored_credential:)
        Passkey.finish_authentication(
          credential: credential,
          state: state,
          stored_credential: stored_credential,
          config: config
        )
      end

      def start_passkey_authentication(return_to: "/")
        Passkey.start_authentication(return_to: return_to, config: config)
      end

      def finish_passkey_registration(credential:, state:, user_handle:)
        Passkey.finish_registration(
          credential: credential,
          state: state,
          user_handle: user_handle,
          config: config
        )
      end

      def start_passkey_registration(user_handle:, user_name:, exclude_credential_ids: [])
        Passkey.start_registration(
          user_handle: user_handle,
          user_name: user_name,
          exclude_credential_ids: exclude_credential_ids,
          config: config
        )
      end
    end
  end
end
