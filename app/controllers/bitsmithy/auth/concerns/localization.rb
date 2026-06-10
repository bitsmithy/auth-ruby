# frozen_string_literal: true

module Bitsmithy
  module Auth
    module Concerns
      module Localization
        extend ActiveSupport::Concern

        ROOT_PATH = "bitsmithy_auth"

        private

        def error_msg(symbol)
          I18n.t("#{ROOT_PATH}.errors.#{symbol}")
        end
      end
    end
  end
end
