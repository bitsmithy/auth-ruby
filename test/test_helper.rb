# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "bitsmithy/auth"

require "minitest/autorun"
require "mocha/minitest"
require_relative "support/rails_env_stub"
require_relative "support/config_helper"
