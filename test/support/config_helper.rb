# frozen_string_literal: true

module ConfigHelper
  def setup
    super
    Bitsmithy::Auth.reset_config!
  end

  def configure_for_tests
    Bitsmithy::Auth.configure do |c|
      c.signing_key = "x" * 64
    end
    Bitsmithy::Auth.test_mode!
  end
end
