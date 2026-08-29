# frozen_string_literal: true

require_relative "../../test_helper"

class TestPasskeyAuthentication < Minitest::Test
  VerifiedCredential = Data.define(:id, :sign_count)

  class VerifyingRelyingParty
    attr_reader :user_verification

    def verify_authentication(_credential, _challenge, **verification)
      @user_verification = verification.values_at(:user_presence, :user_verification).all?
      VerifiedCredential.new(id: "credential-id", sign_count: 4)
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

  def test_finishes_authentication_as_passkey_evidence_with_counter_update
    ceremony = Bitsmithy::Auth.start_passkey_authentication
    relying_party = VerifyingRelyingParty.new
    Bitsmithy::Auth.config.passkey_relying_party = relying_party

    result = finish_authentication(ceremony)

    assert_passkey_evidence(result)
    assert_predicate relying_party, :user_verification
  end

  def test_starts_discoverable_authentication_with_local_user_verification
    ceremony = Bitsmithy::Auth.start_passkey_authentication

    assert_equal [], ceremony.options.fetch("allowCredentials")
    assert_equal "required", ceremony.options.fetch("userVerification")
    assert_predicate ceremony.state, :present?
  end

  private

  def assert_passkey_evidence(result)
    assert_predicate result, :success?
    assert_equal :passkey, result.evidence.sign_in_method
    assert_equal "credential-id", result.evidence.credential_id
    assert_equal "opaque-cook-handle", result.evidence.user_handle
    assert_equal 4, result.evidence.signature_count
  end

  def finish_authentication(ceremony)
    Bitsmithy::Auth.finish_passkey_authentication(
      credential: { "id" => "credential-id" },
      state: ceremony.state,
      stored_credential: stored_credential
    )
  end

  def stored_credential
    Bitsmithy::Auth::Passkey::StoredCredential.new(
      credential_id: "credential-id",
      public_key: "public-key",
      signature_count: 3,
      user_handle: "opaque-cook-handle"
    )
  end
end
