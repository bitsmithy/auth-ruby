# frozen_string_literal: true

require_relative "../engine_helper"

class TestPasskeyRegistrationFlow < ActionDispatch::IntegrationTest
  FakeOptions = Data.define(:challenge) do
    def as_json
      { challenge: challenge }
    end
  end
  VerifiedCredential = Data.define(:id, :public_key, :sign_count)

  class FakeRelyingParty
    def options_for_registration(**)
      FakeOptions.new(challenge: "registration-challenge")
    end

    def verify_registration(*)
      VerifiedCredential.new(id: "credential-id", public_key: "public-key", sign_count: 0)
    end
  end

  setup do
    Bitsmithy::Auth.reset_config!
    @stored_credentials = []
    Bitsmithy::Auth.configure do |config|
      config.envelope_key = "e" * 32
      config.passkey_relying_party = FakeRelyingParty.new
      config.passkey_registration_context = lambda do |_request, _session|
        { user_handle: "cook-handle", user_name: "alex@example.com", exclude_credential_ids: [] }
      end
      config.store_passkey_credential = lambda do |credential, name|
        @stored_credentials << [credential, name]
      end
    end
  end

  test "the host can refuse Passkey registration" do
    Bitsmithy::Auth.config.passkey_registration_context = ->(_request, _session) {}

    get "/auth/passkeys/registration"

    assert_response :forbidden
    assert_empty @stored_credentials
  end

  test "the host authorizes and stores a validated Passkey registration" do
    get "/auth/passkeys/registration"
    ceremony = response.parsed_body

    post "/auth/passkeys/registration", params: {
      credential: { id: "credential-id" },
      state: ceremony.fetch("state"),
      name: "Kitchen laptop"
    }

    assert_response :created
    assert_equal "credential-id", @stored_credentials.fetch(0).fetch(0).credential_id
    assert_equal "Kitchen laptop", @stored_credentials.fetch(0).fetch(1)
  end
end
