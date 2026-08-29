# frozen_string_literal: true

require_relative "../engine_helper"

class TestPasskeyAuthenticationFlow < ActionDispatch::IntegrationTest
  FakeOptions = Data.define(:challenge) do
    def as_json
      { challenge: challenge, allowCredentials: [], userVerification: "required" }
    end
  end
  VerifiedCredential = Data.define(:id, :sign_count)

  class FakeRelyingParty
    def options_for_authentication(**)
      FakeOptions.new(challenge: "authentication-challenge")
    end

    def verify_authentication(*)
      VerifiedCredential.new(id: "credential-id", sign_count: 4)
    end
  end

  setup do
    Bitsmithy::Auth.reset_config!
    @counter_updates = []
    Bitsmithy::Auth.configure do |config|
      config.envelope_key = "e" * 32
      config.passkey_relying_party = FakeRelyingParty.new
      config.find_passkey_credential = ->(_credential_id) { stored_credential }
      config.update_passkey_credential = ->(credential_id, count) { @counter_updates << [credential_id, count] }
      config.on_authenticated = lambda do |evidence, host_session|
        host_session[:passkey_user_handle] = evidence.user_handle
      end
    end
  end

  test "an unknown Passkey fails without establishing a session" do
    Bitsmithy::Auth.config.find_passkey_credential = ->(_credential_id) {}
    get "/auth/passkeys/authentication"
    ceremony = response.parsed_body

    post "/auth/passkeys/authentication", params: {
      credential: { id: "unknown-credential" },
      state: ceremony.fetch("state")
    }

    assert_response :unprocessable_content
    assert_nil session[:passkey_user_handle]
    assert_empty @counter_updates
  end

  test "validated Passkey evidence establishes the host-owned session" do
    get "/auth/passkeys/authentication", params: { return_to: "/recipes" }
    ceremony = response.parsed_body

    post "/auth/passkeys/authentication", params: {
      credential: { id: "credential-id" },
      state: ceremony.fetch("state")
    }

    assert_redirected_to "/recipes"
    assert_equal "opaque-cook-handle", session[:passkey_user_handle]
    assert_equal [["credential-id", 4]], @counter_updates
  end

  private

  def stored_credential
    Bitsmithy::Auth::Passkey::StoredCredential.new(
      credential_id: "credential-id",
      public_key: "public-key",
      signature_count: 3,
      user_handle: "opaque-cook-handle"
    )
  end
end
