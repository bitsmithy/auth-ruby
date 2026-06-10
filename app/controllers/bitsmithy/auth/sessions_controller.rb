# frozen_string_literal: true

module Bitsmithy
  module Auth
    class SessionsController < ::ApplicationController
      include Bitsmithy::Auth::Controller
      include Concerns::Localization

      def new
        render "bitsmithy/auth/sessions/new"
      end

      def create
        phone = params[:phone]
        result = Bitsmithy::Auth.send_code(phone)

        if result.success?
          session[:bitsmithy_auth_pending_phone] = phone
          redirect_to "/auth/code"
        else
          @error = error_msg(result.error)
          render :new
        end
      end

      def edit
        render "bitsmithy/auth/sessions/edit"
      end

      def update
        phone = session[:bitsmithy_auth_pending_phone]
        result = Bitsmithy::Auth.verify_code(phone, params[:code])

        if result.success?
          handle_verify_success(result)
        else
          @error = error_msg(result.error)
          render :edit
        end
      end

      def destroy
        sign_out
        redirect_to Bitsmithy::Auth.config.after_sign_out_path
      end

      private

      def handle_verify_success(result)
        sign_in(token: result.token)
        session.delete(:bitsmithy_auth_pending_phone)
        Bitsmithy::Auth.config.on_verified&.call(current_identity)
        redirect_to Bitsmithy::Auth.config.after_sign_in_path
      end
    end
  end
end
