# frozen_string_literal: true

require_relative "dummy/config/environment"
require "rails/test_help"
require "mocha/minitest"

module ActiveSupport
  class TestCase
    setup { Rails.cache.clear }
  end
end
