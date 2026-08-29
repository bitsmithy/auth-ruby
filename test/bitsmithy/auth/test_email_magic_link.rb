# frozen_string_literal: true

require_relative "../../test_helper"

class TestEmailMagicLink < Minitest::Test
  def setup
    super
    Bitsmithy::Auth.reset_config!
    @deliveries = []
    @now = Time.utc(2026, 8, 28, 12, 0, 0)
    Bitsmithy::Auth.configure do |config|
      config.envelope_key = "e" * 32
      config.magic_link_delivery = ->(message) { @deliveries << message }
      config.clock = -> { @now }
    end
  end

  def test_requests_a_magic_link_for_the_normalized_email
    result = request_magic_link("  Alex+Meals@Example.COM ")

    assert_predicate result, :success?
    assert_equal "alex+meals@example.com", result.metadata.fetch(:email)
    assert_equal 1, @deliveries.length
    assert_equal "alex+meals@example.com", @deliveries.fetch(0).to
    assert_match %r{\Ahttps://cookmark\.example/auth/email#credential=}, @deliveries.fetch(0).url
  end

  def test_tampered_magic_link_returns_a_safe_failure
    credential = request_credential
    tamper_index = credential.length / 2
    replacement = credential[tamper_index] == "x" ? "y" : "x"
    tampered = credential.dup.tap { |value| value[tamper_index] = replacement }

    result = Bitsmithy::Auth.verify_email_magic_link(tampered)

    assert_equal :invalid_magic_link, result.error
    assert_nil result.evidence
  end

  def test_expired_magic_link_returns_a_safe_failure
    credential = request_credential
    @now += 601

    result = Bitsmithy::Auth.verify_email_magic_link(credential)

    assert_equal :expired_magic_link, result.error
  end

  def test_verifies_a_magic_link_as_email_authentication_evidence
    result = Bitsmithy::Auth.verify_email_magic_link(request_credential)

    assert_predicate result, :success?
    assert_equal :email, result.evidence.sign_in_method
    assert_equal "alex@example.com", result.evidence.email
    assert_equal @now, result.evidence.authenticated_at
    assert_predicate result.evidence.replay_id, :present?
  end

  private

  def request_credential
    request_magic_link("alex@example.com")
    URI.parse(@deliveries.fetch(0).url).fragment.delete_prefix("credential=")
  end

  def request_magic_link(email)
    Bitsmithy::Auth.request_email_magic_link(
      email: email,
      redirect_uri: "https://cookmark.example/auth/email"
    )
  end
end
