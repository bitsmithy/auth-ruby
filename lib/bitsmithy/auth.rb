# frozen_string_literal: true

require_relative "auth/version"
require_relative "auth/errors"
require_relative "auth/config"
require_relative "auth/result"
require_relative "auth/authentication_evidence"
require_relative "auth/authorization_request"
require_relative "auth/apple"
require_relative "auth/email"
require_relative "auth/envelope"
require_relative "auth/magic_link"
require_relative "auth/passkey"
require_relative "auth/passkey_methods"
require_relative "auth/google"
require_relative "auth/testing"

require_relative "auth/engine" if defined?(Rails::Engine)

module Bitsmithy
  module Auth
    extend PasskeyMethods

    class << self
      def config
        @config ||= Config.new
      end

      def configure
        yield config
        config
      end

      def start_apple_authentication(redirect_uri:, return_to:)
        Apple.start(redirect_uri: redirect_uri, return_to: return_to, config: config)
      end

      def finish_apple_authentication(code:, state:, redirect_uri:)
        Apple.finish(code: code, state: state, redirect_uri: redirect_uri, config: config)
      end

      def start_google_authentication(redirect_uri:, return_to:)
        Google.start(redirect_uri: redirect_uri, return_to: return_to, config: config)
      end

      def finish_google_authentication(code:, state:, redirect_uri:)
        Google.finish(code: code, state: state, redirect_uri: redirect_uri, config: config)
      end

      def normalize_email(input)
        Email.normalize(input)
      end

      def request_email_magic_link(email:, redirect_uri:)
        MagicLink.request(email: email, redirect_uri: redirect_uri, config: config)
      end

      def verify_email_magic_link(credential)
        MagicLink.verify(credential, config: config)
      end

      def reset_config!
        @config = nil
      end
    end
  end
end
