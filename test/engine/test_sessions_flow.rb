# frozen_string_literal: true

require_relative "../engine_helper"

class TestSessionsFlow < ActionDispatch::IntegrationTest # rubocop:disable Metrics/ClassLength
  setup do
    Bitsmithy::Auth.reset_config!
    Bitsmithy::Auth.configure { |c| c.signing_key = "x" * 64 }
    Bitsmithy::Auth.test_mode!
  end

  test "GET sign-in route renders the phone entry template" do
    get "/auth/sign_in"

    assert_response :ok
    assert_select "input[type='tel']"
  end

  test "POST send_code stores pending phone and redirects to code form" do
    post "/auth/send_code", params: { phone: "+12125551234" }

    assert_redirected_to "/auth/code"
    assert_equal "+12125551234", session[:bitsmithy_auth_pending_phone]
  end

  test "POST send_code with invalid phone re-renders form with error" do
    post "/auth/send_code", params: { phone: "not-a-phone" }

    assert_response :ok
    assert_select "input[type='tel']"
    assert_select "div.error", I18n.t("bitsmithy_auth.errors.invalid_phone_number")
  end

  test "POST send_code when rate-limited re-renders form with rate limit error" do
    phone = "+12125551234"

    # Replace the rate limiter with one that always raises RateLimited
    rate_limiter = Object.new
    rate_limiter.define_singleton_method(:check!) { |_| raise Bitsmithy::Auth::RateLimited }
    Bitsmithy::Auth.stubs(:rate_limiter).returns(rate_limiter)

    post "/auth/send_code", params: { phone: phone }

    assert_response :ok
    assert_select "input[type='tel']"
    assert_select "div.error", I18n.t("bitsmithy_auth.errors.rate_limited")
  end

  test "POST verify with magic code signs in and redirects to root" do
    post "/auth/send_code", params: { phone: "+12125551234" }

    assert_redirected_to "/auth/code"
    follow_redirect!

    post "/auth/verify", params: { code: "000000" }

    assert_redirected_to "/"
    assert_predicate session[:bitsmithy_auth_token], :present?
    assert_nil session[:bitsmithy_auth_pending_phone]
  end

  test "POST verify with wrong code re-renders code form with error and retains pending phone" do
    post "/auth/send_code", params: { phone: "+12125551234" }
    follow_redirect!

    post "/auth/verify", params: { code: "wrong" }

    assert_response :ok
    assert_select "div.error", I18n.t("bitsmithy_auth.errors.invalid_code")
    assert_equal "+12125551234", session[:bitsmithy_auth_pending_phone]
  end

  test "POST verify redirects to configured after_sign_in_path" do
    old_path = Bitsmithy::Auth.config.after_sign_in_path
    Bitsmithy::Auth.config.after_sign_in_path = "/dashboard"

    post "/auth/send_code", params: { phone: "+12125551234" }
    follow_redirect!
    post "/auth/verify", params: { code: "000000" }

    assert_redirected_to "/dashboard"
  ensure
    Bitsmithy::Auth.config.after_sign_in_path = old_path
  end

  test "DELETE sign_out clears session and redirects to root" do
    post "/auth/send_code", params: { phone: "+12125551234" }
    follow_redirect!
    post "/auth/verify", params: { code: "000000" }

    assert_predicate session[:bitsmithy_auth_token], :present?

    delete "/auth/sign_out"

    assert_redirected_to "/"
    assert_nil session[:bitsmithy_auth_token]
  end

  test "DELETE sign_out redirects to configured after_sign_out_path" do
    old_path = Bitsmithy::Auth.config.after_sign_out_path
    Bitsmithy::Auth.config.after_sign_out_path = "/goodbye"

    post "/auth/send_code", params: { phone: "+12125551234" }
    follow_redirect!
    post "/auth/verify", params: { code: "000000" }

    assert_predicate session[:bitsmithy_auth_token], :present?

    delete "/auth/sign_out"

    assert_redirected_to "/goodbye"
  ensure
    Bitsmithy::Auth.config.after_sign_out_path = old_path
  end

  test "on_verified callback fires on successful verify and receives the identity" do
    verified_identity = nil
    Bitsmithy::Auth.config.on_verified = ->(identity) { verified_identity = identity }

    post "/auth/send_code", params: { phone: "+12125551234" }
    follow_redirect!
    post "/auth/verify", params: { code: "000000" }

    assert_redirected_to "/"
    assert_equal "+12125551234", verified_identity.phone
  end

  test "on_verified callback does not fire on failed verify" do
    callback_fired = false
    Bitsmithy::Auth.config.on_verified = ->(_identity) { callback_fired = true }

    post "/auth/send_code", params: { phone: "+12125551234" }
    follow_redirect!
    post "/auth/verify", params: { code: "wrong" }

    assert_response :ok
    assert_not callback_fired, "on_verified should not fire on wrong code"
  end

  test "require_authentication! redirects unauthenticated to sign_in_path" do
    get "/test"

    assert_redirected_to Bitsmithy::Auth::Engine.routes.url_helpers.sign_in_path
  end

  test "require_authentication! allows authenticated requests through" do
    post "/auth/send_code", params: { phone: "+12125551234" }
    follow_redirect!
    post "/auth/verify", params: { code: "000000" }

    get "/test"

    assert_response :ok
    assert_equal "OK", response.body
  end

  test "require_authentication! redirects to configured sign_in_path override" do
    old_path = Bitsmithy::Auth.config.sign_in_path
    Bitsmithy::Auth.config.sign_in_path = "/custom-sign-in"

    get "/test"

    assert_redirected_to "/custom-sign-in"
  ensure
    Bitsmithy::Auth.config.sign_in_path = old_path
  end
end
