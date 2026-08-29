# frozen_string_literal: true

module Bitsmithy
  module Auth
    class FederatedAuthenticationsController < ::ApplicationController
      include Concerns::Localization

      def new
        render "bitsmithy/auth/federated_authentications/new"
      end

      def apple
        authorization = Bitsmithy::Auth.start_apple_authentication(
          redirect_uri: Bitsmithy::Auth.config.apple_redirect_uri,
          return_to: params[:return_to].presence || "/"
        )
        redirect_to authorization.url, allow_other_host: true
      end

      def apple_callback
        result = apple_result
        return render_failure(result) unless result.success?

        complete_authentication(result)
      end

      def google
        authorization = Bitsmithy::Auth.start_google_authentication(
          redirect_uri: Bitsmithy::Auth.config.google_redirect_uri,
          return_to: params[:return_to].presence || "/"
        )
        redirect_to authorization.url, allow_other_host: true
      end

      def google_callback
        result = google_result
        return render_failure(result) unless result.success?

        complete_authentication(result)
      end

      private

      def apple_result
        Bitsmithy::Auth.finish_apple_authentication(
          code: params[:code],
          state: params[:state],
          redirect_uri: Bitsmithy::Auth.config.apple_redirect_uri
        )
      end

      def complete_authentication(result)
        reset_session
        Bitsmithy::Auth.config.on_authenticated.call(result.evidence, session)
        redirect_to result.metadata.fetch(:return_to)
      end

      def google_result
        Bitsmithy::Auth.finish_google_authentication(
          code: params[:code],
          state: params[:state],
          redirect_uri: Bitsmithy::Auth.config.google_redirect_uri
        )
      end

      def render_failure(result)
        @error = error_msg(result.error)
        render "bitsmithy/auth/federated_authentications/error", status: :unprocessable_content
      end
    end
  end
end
