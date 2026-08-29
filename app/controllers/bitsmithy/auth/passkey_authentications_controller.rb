# frozen_string_literal: true

module Bitsmithy
  module Auth
    class PasskeyAuthenticationsController < ::ApplicationController
      def show
        ceremony = Bitsmithy::Auth.start_passkey_authentication(
          return_to: params[:return_to].presence || "/"
        )
        render json: { publicKey: ceremony.options, state: ceremony.state }
      end

      def create
        stored = Bitsmithy::Auth.config.find_passkey_credential.call(params.dig(:credential, :id))
        return render_failure unless stored

        result = finish_authentication(stored)
        return render_failure unless result.success?

        complete_authentication(result)
      end

      private

      def complete_authentication(result)
        evidence = result.evidence
        Bitsmithy::Auth.config.update_passkey_credential.call(evidence.credential_id, evidence.signature_count)
        reset_session
        Bitsmithy::Auth.config.on_authenticated.call(evidence, session)
        redirect_to result.metadata.fetch(:return_to)
      end

      def credential_param
        params.expect(
          credential: [
            :id, :rawId, :type,
            { response: %i[clientDataJSON authenticatorData signature userHandle] }
          ]
        ).to_h
      end

      def finish_authentication(stored)
        Bitsmithy::Auth.finish_passkey_authentication(
          credential: credential_param,
          state: params[:state],
          stored_credential: stored
        )
      end

      def render_failure
        render json: { error: :invalid_passkey_authentication }, status: :unprocessable_content
      end
    end
  end
end
