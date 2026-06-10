# frozen_string_literal: true

if defined?(Rails::Engine)
  module Bitsmithy
    module Auth
      class Engine < ::Rails::Engine
        isolate_namespace Bitsmithy::Auth
      end
    end
  end
end
