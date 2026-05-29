# frozen_string_literal: true

# Minimal Rails environment shim so tests can exercise the
# `Bitsmithy::Auth.test_mode!` env guard without booting Rails.
# Each test starts with Rails.env == RailsEnvStub.new(:test) via
# ConfigHelper#setup. Tests that need other envs override Rails.env
# directly. Tests that need to simulate "Rails is not defined"
# remove the Rails constant and restore it in an `ensure` block.

class RailsEnvStub
  def initialize(name)
    @name = name.to_s
  end

  def test?
    @name == "test"
  end

  def development?
    @name == "development"
  end
end

module Rails
  class << self
    attr_accessor :env
  end
end
Rails.env = RailsEnvStub.new(:test)
