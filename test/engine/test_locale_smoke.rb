# frozen_string_literal: true

require_relative "../engine_helper"

class LocaleSmokeTest < ActiveSupport::TestCase
  test "every engine-surfaced error symbol has a non-missing en translation" do
    error_symbols = %i[
      apple_unavailable expired_magic_link google_unavailable
      invalid_apple_authentication invalid_email invalid_google_authentication
      invalid_magic_link rate_limited used_magic_link
    ]

    error_symbols.each do |symbol|
      translation = I18n.t("bitsmithy_auth.errors.#{symbol}")

      refute_match(/translation missing/i, translation,
                   "Expected bitsmithy_auth.errors.#{symbol} to resolve, got: #{translation}")
    end
  end
end
