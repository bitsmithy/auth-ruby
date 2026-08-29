# frozen_string_literal: true

module ConfigHelper
  def setup
    super
    Bitsmithy::Auth.reset_config!
    Rails.env = RailsEnvStub.new(:test)
  end
end
