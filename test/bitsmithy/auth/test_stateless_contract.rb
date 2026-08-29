# frozen_string_literal: true

require_relative "../../test_helper"

class TestStatelessContract < Minitest::Test
  def test_public_api_does_not_own_application_identity_or_sessions
    legacy_methods = %i[
      send_code verify_code decode_token normalize_phone redact_phone
      sign_in sign_out current_identity authenticated? require_authentication!
    ]

    legacy_methods.each do |method_name|
      refute_respond_to Bitsmithy::Auth, method_name
    end
  end
end
