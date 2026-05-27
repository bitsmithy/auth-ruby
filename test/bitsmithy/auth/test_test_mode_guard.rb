# frozen_string_literal: true

require "test_helper"

module Bitsmithy
  module Auth
    class TestTestModeGuard < Minitest::Test
      include ConfigHelper

      def test_test_mode_raises_configuration_error_in_rails_production_env
        Rails.env = RailsEnvStub.new(:production)
        Bitsmithy::Auth.configure { |c| c.signing_key = "x" * 64 }

        assert_raises(Bitsmithy::Auth::ConfigurationError) do
          Bitsmithy::Auth.test_mode!
        end
      end

      def test_test_mode_succeeds_in_rails_development_env
        Rails.env = RailsEnvStub.new(:development)
        Bitsmithy::Auth.configure { |c| c.signing_key = "x" * 64 }

        Bitsmithy::Auth.test_mode!

        assert_kind_of Bitsmithy::Auth::OTP::TestAdapter, Bitsmithy::Auth.config.otp_adapter
      end

      def test_test_mode_raises_when_rails_is_not_defined
        preserved_rails = Rails
        Object.send(:remove_const, :Rails)
        Bitsmithy::Auth.configure { |c| c.signing_key = "x" * 64 }

        assert_raises(Bitsmithy::Auth::ConfigurationError) do
          Bitsmithy::Auth.test_mode!
        end
      ensure
        Object.const_set(:Rails, preserved_rails) if preserved_rails
      end

      def test_test_mode_error_message_names_the_allowed_environments
        Rails.env = RailsEnvStub.new(:production)
        Bitsmithy::Auth.configure { |c| c.signing_key = "x" * 64 }

        error = assert_raises(Bitsmithy::Auth::ConfigurationError) do
          Bitsmithy::Auth.test_mode!
        end

        assert_includes error.message, "test"
        assert_includes error.message, "development"
      end
    end
  end
end
