# frozen_string_literal: true

module Bitsmithy
  module Auth
    class EmailMagicLinksController < ::ApplicationController
      include Concerns::Localization

      def new
        render "bitsmithy/auth/email_magic_links/new"
      end

      def create
        email = Bitsmithy::Auth.normalize_email(params[:email])
        return render_rate_limited unless email_request_allowed?(email)

        render_request_result(request_magic_link(email))
      rescue InvalidEmail
        render_failure(Result.failure(error: :invalid_email))
      end

      def exchange
        render "bitsmithy/auth/email_magic_links/exchange"
      end

      def sent
        render "bitsmithy/auth/email_magic_links/sent"
      end

      def verify
        result = Bitsmithy::Auth.verify_email_magic_link(params[:credential])
        return render_failure(result) unless result.success?
        return render_failure(Result.failure(error: :used_magic_link)) unless claim(result.evidence.replay_id)

        complete_authentication(result.evidence)
      end

      private

      def claim(replay_id)
        Bitsmithy::Auth.config.claim_magic_link.call(replay_id)
      end

      def complete_authentication(evidence)
        reset_session
        Bitsmithy::Auth.config.on_authenticated.call(evidence, session)
        redirect_to Bitsmithy::Auth.config.after_authentication_path
      end

      def email_request_allowed?(email)
        Bitsmithy::Auth.config.allow_email_request.call(email, request)
      end

      def render_rate_limited
        render_failure(Result.failure(error: :rate_limited), status: :too_many_requests)
      end

      def render_request_result(result)
        return render_failure(result) unless result.success?

        redirect_to email_magic_link_sent_path
      end

      def request_magic_link(email)
        Bitsmithy::Auth.request_email_magic_link(
          email: email,
          redirect_uri: Bitsmithy::Auth.config.magic_link_redirect_uri
        )
      end

      def render_failure(result, status: :unprocessable_content)
        @error = error_msg(result.error)
        render "bitsmithy/auth/email_magic_links/error", status: status
      end
    end
  end
end
