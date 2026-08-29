# frozen_string_literal: true

require_relative "../../test_helper"

class TestPasskeyRegistration < Minitest::Test
  VerifiedCredential = Data.define(:id, :public_key, :sign_count)

  class VerifyingRelyingParty
    attr_reader :challenge, :user_verification

    def verify_registration(_credential, challenge, user_presence:, user_verification:)
      @challenge = challenge
      @user_verification = user_presence && user_verification
      VerifiedCredential.new(id: "new-credential", public_key: "public-key", sign_count: 0)
    end
  end

  def setup
    super
    Bitsmithy::Auth.reset_config!
    Bitsmithy::Auth.configure do |config|
      config.envelope_key = "e" * 32
      config.passkey_origin = "https://cookmark.example"
      config.passkey_relying_party_id = "cookmark.example"
      config.passkey_relying_party_name = "Cookmark"
    end
  end

  def test_finishes_registration_with_persistence_ready_public_values
    ceremony = start_registration
    relying_party = VerifyingRelyingParty.new
    Bitsmithy::Auth.config.passkey_relying_party = relying_party

    result = finish_registration(ceremony)

    assert_registered_credential(result)
    assert_predicate relying_party, :user_verification
  end

  def test_starts_discoverable_registration_with_local_user_verification
    ceremony = start_registration

    assert_registration_options(ceremony.options)
    assert_predicate ceremony.state, :present?
  end

  private

  def assert_registered_credential(result)
    credential = result.metadata.fetch(:credential)

    assert_predicate result, :success?
    assert_equal "new-credential", credential.credential_id
    assert_equal "public-key", credential.public_key
    assert_equal 0, credential.signature_count
  end

  def assert_registration_options(options)
    assert_equal "required", options.dig("authenticatorSelection", "residentKey")
    assert_equal "required", options.dig("authenticatorSelection", "userVerification")
    assert_equal "none", options.fetch("attestation")
    credential_ids = options.fetch("excludeCredentials").map { |credential| credential.fetch("id") }

    assert_equal ["existing-credential"], credential_ids
  end

  def finish_registration(ceremony)
    Bitsmithy::Auth.finish_passkey_registration(
      credential: { "id" => "new-credential" },
      state: ceremony.state,
      user_handle: "opaque-cook-handle"
    )
  end

  def start_registration
    Bitsmithy::Auth.start_passkey_registration(
      user_handle: "opaque-cook-handle",
      user_name: "alex@example.com",
      exclude_credential_ids: ["existing-credential"]
    )
  end
end
