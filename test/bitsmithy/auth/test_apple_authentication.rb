# frozen_string_literal: true

require_relative "../../test_helper"

class TestAppleAuthentication < Minitest::Test
  FakeProvider = Data.define(:id_token, :jwks) do
    def exchange(**)
      { "id_token" => id_token }
    end
  end

  def setup
    super
    Bitsmithy::Auth.reset_config!
    Bitsmithy::Auth.configure do |config|
      config.envelope_key = "e" * 32
      config.apple_client_id = "com.cookmark.web"
      config.apple_client_secret = "test-client-secret"
      config.clock = -> { Time.utc(2026, 8, 28, 12, 0, 0) }
    end
  end

  def test_returning_apple_subject_can_omit_the_email
    configure_provider(id_token_for(apple_parameters.fetch("nonce"), include_email: false))

    result = finish_apple

    assert_predicate result, :success?
    assert_equal "apple-subject", result.evidence.subject
    assert_nil result.evidence.email
  end

  def test_finishes_apple_private_relay_as_federated_authentication_evidence
    configure_provider(id_token_for(apple_parameters.fetch("nonce")))

    result = finish_apple

    assert_apple_private_relay_evidence(result)
  end

  def test_starts_apple_with_email_scope_form_post_and_pkce
    parameters = apple_parameters

    assert_equal "email", parameters.fetch("scope")
    assert_equal "form_post", parameters.fetch("response_mode")
    assert_equal "code", parameters.fetch("response_type")
    assert_equal "S256", parameters.fetch("code_challenge_method")
    assert_predicate parameters.fetch("nonce"), :present?
    assert_predicate parameters.fetch("state"), :present?
  end

  private

  def apple_parameters
    @apple_parameters ||= begin
      authorization = Bitsmithy::Auth.start_apple_authentication(
        redirect_uri: "https://cookmark.example/auth/apple/callback",
        return_to: "/recipes"
      )
      URI.decode_www_form(URI.parse(authorization.url).query).to_h
    end
  end

  def assert_apple_private_relay_evidence(result)
    assert_predicate result, :success?
    assert_equal :apple, result.evidence.sign_in_method
    assert_equal "apple-subject", result.evidence.subject
    assert_equal "relay@privaterelay.appleid.com", result.evidence.email
    assert_equal "/recipes", result.metadata.fetch(:return_to)
  end

  def configure_provider(id_token)
    jwk = JWT::JWK.new(@signing_key.public_key, kid: "apple-test-key").export
    Bitsmithy::Auth.config.apple_provider_client = FakeProvider.new(
      id_token: id_token,
      jwks: { "keys" => [jwk] }
    )
  end

  def finish_apple
    Bitsmithy::Auth.finish_apple_authentication(
      code: "authorization-code",
      state: apple_parameters.fetch("state"),
      redirect_uri: "https://cookmark.example/auth/apple/callback"
    )
  end

  def id_token_for(nonce, include_email: true)
    @signing_key = OpenSSL::PKey::RSA.generate(2048)
    claims = id_token_claims(nonce)
    claims.merge!(email_claims) if include_email
    JWT.encode(claims, @signing_key, "RS256", kid: "apple-test-key")
  end

  def id_token_claims(nonce)
    {
      iss: "https://appleid.apple.com",
      aud: "com.cookmark.web",
      sub: "apple-subject",
      nonce: nonce,
      iat: Time.utc(2026, 8, 28, 12, 0, 0).to_i,
      exp: Time.utc(2026, 8, 28, 12, 10, 0).to_i
    }
  end

  def email_claims
    {
      email: "relay@privaterelay.appleid.com",
      email_verified: "true",
      is_private_email: "true"
    }
  end
end
