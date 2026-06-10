# frozen_string_literal: true

require_relative "../engine_helper"

class LocaleSmokeTest < ActiveSupport::TestCase
  test "every engine-surfaced error symbol has a non-missing en translation" do
    error_symbols = %i[
      invalid_phone_number
      rate_limited
      invalid_code
    ]

    error_symbols.each do |symbol|
      translation = I18n.t("bitsmithy_auth.errors.#{symbol}")

      refute_match(/translation missing/i, translation,
                   "Expected bitsmithy_auth.errors.#{symbol} to resolve, got: #{translation}")
    end
  end
end
