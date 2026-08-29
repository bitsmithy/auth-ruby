# frozen_string_literal: true

require_relative "../engine_helper"

class TestAppleAuthenticationFlow < ActionDispatch::IntegrationTest
  setup do
    Bitsmithy::Auth.reset_config!
    @provider = Object.new
    @provider.define_singleton_method(:jwks) { @jwks }
    @provider.define_singleton_method(:exchange) { |**| { "id_token" => @id_token } }
    Bitsmithy::Auth.configure do |config|
      config.envelope_key = "e" * 32
      config.apple_client_id = "com.cookmark.web"
      config.apple_client_secret = "test-client-secret"
      config.apple_provider_client = @provider
      config.apple_redirect_uri = "https://cookmark.example/auth/apple/callback"
      config.on_authenticated = lambda do |evidence, host_session|
        host_session[:authenticated_email] = evidence.email
      end
    end
  end

  test "Apple private relay evidence establishes the host-owned session" do
    get "/auth/apple", params: { return_to: "/recipes" }
    parameters = URI.decode_www_form(URI.parse(response.location).query).to_h
    configure_id_token(parameters.fetch("nonce"))

    post "/auth/apple/callback", params: {
      code: "authorization-code",
      state: parameters.fetch("state")
    }

    assert_redirected_to "/recipes"
    assert_equal "relay@privaterelay.appleid.com", session[:authenticated_email]
  end

  private

  def configure_id_token(nonce)
    key = OpenSSL::PKey::RSA.generate(2048)
    @provider.instance_variable_set(
      :@jwks,
      { "keys" => [JWT::JWK.new(key.public_key, kid: "test-key").export] }
    )
    @provider.instance_variable_set(
      :@id_token,
      JWT.encode(id_token_claims(nonce), key, "RS256", kid: "test-key")
    )
  end

  def id_token_claims(nonce)
    {
      iss: "https://appleid.apple.com",
      aud: "com.cookmark.web",
      sub: "apple-subject",
      email: "relay@privaterelay.appleid.com",
      email_verified: "true",
      nonce: nonce
    }.merge(token_times)
  end

  def token_times
    now = Time.now.utc.to_i
    { iat: now, exp: now + 600 }
  end
end
