# frozen_string_literal: true

require "test_helper"

module Bitsmithy
  class TestAuth < Minitest::Test
    def test_that_it_has_a_version_number
      refute_nil ::Bitsmithy::Auth::VERSION
    end
  end
end
