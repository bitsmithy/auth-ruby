# frozen_string_literal: true

require_relative "../../test_helper"

class TestGoogleAuthentication < Minitest::Test
  FakeProvider = Data.define(:id_token, :jwks) do
    def exchange(**)
      raise Bitsmithy::Auth::ProviderUnavailable unless id_token

      { "id_token" => id_token }
    end
  end

  def setup
    super
    Bitsmithy::Auth.reset_config!
    Bitsmithy::Auth.configure do |config|
      config.envelope_key = "e" * 32
      config.google_client_id = "google-client-id"
      config.clock = -> { Time.utc(2026, 8, 28, 12, 0, 0) }
    end
  end

  def test_google_service_failure_returns_a_safe_result
    Bitsmithy::Auth.config.google_provider_client = FakeProvider.new(id_token: nil, jwks: {})

    result = finish_google

    assert_equal :google_unavailable, result.error
    assert_nil result.evidence
  end

  def test_finishes_google_as_federated_authentication_evidence
    configure_provider(id_token_for(google_parameters.fetch("nonce")))

    result = finish_google

    assert_google_evidence(result)
  end

  def test_starts_google_with_minimal_identity_scopes_and_pkce
    parameters = google_parameters

    assert_equal "openid email", parameters.fetch("scope")
    assert_equal "code", parameters.fetch("response_type")
    assert_equal "S256", parameters.fetch("code_challenge_method")
    assert_predicate parameters.fetch("nonce"), :present?
    assert_predicate parameters.fetch("state"), :present?
  end

  private

  def assert_google_evidence(result)
    assert_predicate result, :success?
    assert_equal :google, result.evidence.sign_in_method
    assert_equal "google-subject", result.evidence.subject
    assert_equal "alex@example.com", result.evidence.email
    assert_equal "/recipes", result.metadata.fetch(:return_to)
  end

  def configure_provider(id_token)
    jwk = JWT::JWK.new(@signing_key.public_key, kid: "test-key").export
    Bitsmithy::Auth.config.google_provider_client = FakeProvider.new(
      id_token: id_token,
      jwks: { "keys" => [jwk] }
    )
  end

  def finish_google
    Bitsmithy::Auth.finish_google_authentication(
      code: "authorization-code",
      state: google_parameters.fetch("state"),
      redirect_uri: "https://cookmark.example/auth/google/callback"
    )
  end

  def google_parameters
    @google_parameters ||= begin
      authorization = Bitsmithy::Auth.start_google_authentication(
        redirect_uri: "https://cookmark.example/auth/google/callback",
        return_to: "/recipes"
      )
      URI.decode_www_form(URI.parse(authorization.url).query).to_h
    end
  end

  def id_token_for(nonce)
    @signing_key = OpenSSL::PKey::RSA.generate(2048)
    JWT.encode(id_token_claims(nonce), @signing_key, "RS256", kid: "test-key")
  end

  def id_token_claims(nonce)
    {
      iss: "https://accounts.google.com",
      aud: "google-client-id",
      sub: "google-subject",
      email: "Alex@Example.com",
      email_verified: true,
      nonce: nonce,
      iat: Time.utc(2026, 8, 28, 12, 0, 0).to_i,
      exp: Time.utc(2026, 8, 28, 12, 10, 0).to_i
    }
  end
end
