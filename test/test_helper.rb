# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

# Load every gem source file so test files don't need to track their own
# per-test requires. Each lib file declares its own require_relative chain;
# this just ensures none are missed under the bitsmithy-auth tree.
Dir[File.expand_path("../lib/bitsmithy/**/*.rb", __dir__)].each { |f| require f }

require "minitest/autorun"
require "mocha/minitest"
require_relative "support/rails_env_stub"
require_relative "support/config_helper"
