# frozen_string_literal: true

require "active_support/concern"

module Bitsmithy
  module Auth
    module Controller
      extend ActiveSupport::Concern

      SESSION_KEY = :bitsmithy_auth_token

      def current_identity
        return @current_identity if defined?(@current_identity)

        @current_identity = begin
          token = session[SESSION_KEY]
          token && Bitsmithy::Auth.decode_token(token)
        rescue Bitsmithy::Auth::InvalidToken
          nil
        end
      end

      def current_phone
        current_identity&.phone
      end

      def authenticated?
        !current_identity.nil?
      end

      def sign_in(token:)
        session[SESSION_KEY] = token
        remove_instance_variable(:@current_identity) if defined?(@current_identity)
      end

      def sign_out
        session.delete(SESSION_KEY)
        remove_instance_variable(:@current_identity) if defined?(@current_identity)
      end
    end
  end
end
