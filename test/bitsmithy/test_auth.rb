# frozen_string_literal: true

require "test_helper"

module Bitsmithy
  class TestAuth < Minitest::Test
    include ConfigHelper

    def test_that_it_has_a_version_number
      refute_nil ::Bitsmithy::Auth::VERSION
    end

    def test_config_validate_requires_the_stateless_host_contract
      config = Bitsmithy::Auth::Config.new

      error = assert_raises(Bitsmithy::Auth::ConfigurationError) { config.validate! }

      assert_match(/envelope_key/, error.message)
      assert_match(/on_authenticated/, error.message)
    end

    def test_config_validate_accepts_the_minimum_stateless_host_contract
      config = Bitsmithy::Auth::Config.new
      config.envelope_key = "e" * 32
      config.on_authenticated = ->(_evidence, _session) {}

      assert_predicate config, :validate!
    end
  end
end
