# frozen_string_literal: true

require_relative "../../test_helper"

class TestAppleClientSecret < Minitest::Test
  def setup
    super
    Bitsmithy::Auth.reset_config!
    @private_key = OpenSSL::PKey::EC.generate("prime256v1")
    Bitsmithy::Auth.configure do |config|
      config.apple_client_id = "com.cookmark.web"
      config.apple_team_id = "TEAM123"
      config.apple_key_id = "KEY123"
      config.apple_private_key = @private_key.to_pem
      config.clock = -> { Time.utc(2026, 8, 28, 12, 0, 0) }
    end
  end

  def test_builds_the_apple_client_secret_from_host_credentials
    client_secret = Bitsmithy::Auth.config.apple_client_secret

    claims, header = JWT.decode(client_secret, @private_key, true, algorithm: "ES256")

    assert_equal "TEAM123", claims.fetch("iss")
    assert_equal "com.cookmark.web", claims.fetch("sub")
    assert_equal "https://appleid.apple.com", claims.fetch("aud")
    assert_equal "KEY123", header.fetch("kid")
  end
end
