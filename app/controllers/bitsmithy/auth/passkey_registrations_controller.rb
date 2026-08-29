# frozen_string_literal: true

module Bitsmithy
  module Auth
    class PasskeyRegistrationsController < ::ApplicationController
      def show
        context = registration_context
        return head :forbidden unless context

        ceremony = Bitsmithy::Auth.start_passkey_registration(**context)
        render json: { publicKey: ceremony.options, state: ceremony.state }
      end

      def create
        context = registration_context
        return head :forbidden unless context

        result = finish_registration(context)
        return render json: { error: result.error }, status: :unprocessable_content unless result.success?

        Bitsmithy::Auth.config.store_passkey_credential.call(result.metadata.fetch(:credential), params[:name])
        head :created
      end

      private

      def credential_param
        params.expect(
          credential: [
            :id, :rawId, :type,
            { response: [:clientDataJSON, :attestationObject, { transports: [] }] }
          ]
        ).to_h
      end

      def finish_registration(context)
        Bitsmithy::Auth.finish_passkey_registration(
          credential: credential_param,
          state: params[:state],
          user_handle: context.fetch(:user_handle)
        )
      end

      def registration_context
        Bitsmithy::Auth.config.passkey_registration_context.call(request, session)
      end
    end
  end
end
