# frozen_string_literal: true

require_relative "../engine_helper"

class TestEmailMagicLinkFlow < ActionDispatch::IntegrationTest
  setup do
    Bitsmithy::Auth.reset_config!
    @deliveries = []
    @claims = []
    Bitsmithy::Auth.configure do |config|
      config.envelope_key = "e" * 32
      config.magic_link_delivery = ->(message) { @deliveries << message }
      config.magic_link_redirect_uri = "https://cookmark.example/auth/email"
      config.claim_magic_link = lambda do |replay_id|
        @claims << replay_id
        true
      end
      config.on_authenticated = lambda do |evidence, host_session|
        host_session[:authenticated_email] = evidence.email
      end
    end
  end

  test "successful email authentication resets the previous session" do
    post "/seed_session"

    assert_equal "old", session[:stale_value]

    post "/auth/email_magic_links", params: { email: "alex@example.com" }
    credential = URI.parse(@deliveries.fetch(0).url).fragment.delete_prefix("credential=")

    post "/auth/email_magic_links/verify", params: { credential: credential }

    assert_nil session[:stale_value]
    assert_equal "alex@example.com", session[:authenticated_email]
  end

  test "a replayed Magic Link cannot establish a host session" do
    Bitsmithy::Auth.config.claim_magic_link = ->(_replay_id) { false }
    post "/auth/email_magic_links", params: { email: "alex@example.com" }
    credential = URI.parse(@deliveries.fetch(0).url).fragment.delete_prefix("credential=")

    post "/auth/email_magic_links/verify", params: { credential: credential }

    assert_response :unprocessable_content
    assert_nil session[:authenticated_email]
    assert_select "[role=alert]", text: I18n.t("bitsmithy_auth.errors.used_magic_link")
  end

  test "host rate limiting prevents email delivery" do
    Bitsmithy::Auth.config.allow_email_request = ->(_email, _request) { false }

    post "/auth/email_magic_links", params: { email: "alex@example.com" }

    assert_response :too_many_requests
    assert_empty @deliveries
  end

  test "email Magic Link evidence establishes the host-owned session" do
    post "/auth/email_magic_links", params: { email: "Alex@Example.com" }
    credential = URI.parse(@deliveries.fetch(0).url).fragment.delete_prefix("credential=")

    post "/auth/email_magic_links/verify", params: { credential: credential }

    assert_redirected_to "/"
    assert_equal "alex@example.com", session[:authenticated_email]
    assert_equal 1, @claims.length
  end
end

class TestDefaultMagicLinkDelivery < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    Bitsmithy::Auth.reset_config!
    Bitsmithy::Auth.configure do |config|
      config.envelope_key = "e" * 32
      config.magic_link_sender = "Cookmark <entry@cookmark.example>"
      config.magic_link_redirect_uri = "https://cookmark.example/auth/email"
    end
  end

  test "RubyAuth enqueues the Magic Link email through Action Mailer" do
    assert_enqueued_emails 1 do
      post "/auth/email_magic_links", params: { email: "alex@example.com" }
    end
  end
end
