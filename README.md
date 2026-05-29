# bitsmithy-auth

Phone-number OTP authentication for Ruby applications. Verify a user by sending them an SMS code; receive a signed Token in return; decode it into an Identity.

This gem is a **verification primitive**, not a user-management system. It does not own a User model, a sessions table, or a phone-change flow. Host apps map verified Phones to their own user records however they want. See [`docs/adr/0003`](docs/adr/0003-verification-primitive-not-user-system.md) for the rationale.

Backed by [Twilio Verify](https://www.twilio.com/docs/verify) — Twilio owns OTP generation, expiry, attempt limits, and SMS-pumping fraud detection. We never store an OTP locally.

## Status — v0.1.0

| In v0.1.0 | Deferred to v0.2.0 |
|---|---|
| Framework-agnostic core API | Mountable Rails engine + default views |
| Rails `Controller` concern (optional) | Install generator |
| Twilio Verify production adapter | Redis-backed rate-limit store |
| Per-Phone rate limiting (in-memory store) | Voice / WhatsApp channels |
| PII-redacting `redact_phone` helper | Email OTP / TOTP |
| `test_mode!` with Rails-env guard | |

## Installation

This is a private gem distributed via the `bitsmithy/auth-ruby` repo on GitHub.

```ruby
# Gemfile
gem "bitsmithy-auth", github: "bitsmithy/auth-ruby"
```

Generate a signing key once per environment and store it in your secrets manager:

```bash
$ ruby -rsecurerandom -e 'puts SecureRandom.hex(32)'
```

## Configuration

```ruby
# config/initializers/bitsmithy_auth.rb
require "bitsmithy/auth"
require "bitsmithy/auth/otp/twilio_adapter"  # only when using Twilio in production

Bitsmithy::Auth.configure do |c|
  c.signing_key               = ENV.fetch("BITSMITHY_AUTH_SIGNING_KEY")
  c.twilio_account_sid        = ENV.fetch("TWILIO_ACCOUNT_SID")
  c.twilio_auth_token         = ENV.fetch("TWILIO_AUTH_TOKEN")
  c.twilio_verify_service_sid = ENV.fetch("TWILIO_VERIFY_SERVICE_SID")
  c.otp_adapter               = Bitsmithy::Auth::OTP::TwilioAdapter.new(c)

  # Optional overrides (defaults shown):
  # c.session_duration = 86_400                            # 24h
  # c.rate_limit       = { per_phone: 5, window: 3_600 }   # 5/hr/phone
end
```

The four required fields above are validated at configure time:

```ruby
Bitsmithy::Auth.config.validate!  # raises ConfigurationError if any is unset
```

## Core API

Five module methods on `Bitsmithy::Auth`. The convention: expected user-input failures return a `Result`; programmer-error or tampering failures raise.

| Method | Returns | Failure mode |
|---|---|---|
| `send_code(phone)` | `Result` | returns failure Result; never raises |
| `verify_code(phone, code)` | `Result` (with `.token` on success) | returns failure Result; never raises |
| `decode_token(token)` | `Identity` | raises `InvalidToken` |
| `normalize_phone(input, country:)` | `String` (E.164) | raises `InvalidPhoneNumber` |
| `redact_phone(phone)` | `String` (masked) | does not fail |

### `Result` shape

```ruby
result = Bitsmithy::Auth.verify_code("+12127363100", "000000")
result.success?  # => true / false
result.error     # => symbol or nil — see "Error vocabulary" below
result.token     # => JWT string (success only) or nil
result.phone     # => E.164 String
result.channel   # => :sms
```

### `Identity` shape

```ruby
identity = Bitsmithy::Auth.decode_token(token)
identity.phone        # => "+12127363100"
identity.issued_at    # => Time
identity.expires_at   # => Time
```

## Rails Controller concern

Loaded automatically when `ActionController` is defined. Include it in your `ApplicationController`:

```ruby
class ApplicationController < ActionController::Base
  include Bitsmithy::Auth::Controller
end
```

You get:

| Method | What it does |
|---|---|
| `current_identity` | Decodes the Token from `session[:bitsmithy_auth_token]`. Memoised per request. Returns `nil` if no token, invalid token, or expired token. |
| `current_phone` | `current_identity&.phone` |
| `authenticated?` | `!current_identity.nil?` |
| `sign_in(token:)` | Writes the Token to session; invalidates the memoised identity |
| `sign_out` | Clears the session key; invalidates the memo |

Deliberately **no `require_authentication!`** — host apps own redirect semantics. The four-line pattern:

```ruby
class ApplicationController < ActionController::Base
  include Bitsmithy::Auth::Controller
  before_action :require_authentication!

  private

  def require_authentication!
    redirect_to sign_in_path unless authenticated?
  end
end
```

## Sign-in controller (host-app code)

Roughly thirty lines. Host apps write their own — the gem does not ship a default sign-in flow in v0.1.0.

```ruby
class SessionsController < ApplicationController
  skip_before_action :require_authentication!

  def new
  end

  def create
    result = Bitsmithy::Auth.send_code(params[:phone])
    if result.success?
      session[:pending_phone] = result.phone
      render :verify
    else
      flash.now[:error] = error_message_for(result.error)
      render :new
    end
  end

  def verify
    result = Bitsmithy::Auth.verify_code(session[:pending_phone], params[:code])
    if result.success?
      sign_in(token: result.token)
      session.delete(:pending_phone)
      redirect_to root_path
    else
      flash.now[:error] = "That code didn't match — try again."
      render :verify
    end
  end

  def destroy
    sign_out
    redirect_to root_path
  end
end
```

## Test mode

```ruby
# test_helper.rb / spec_helper.rb
Bitsmithy::Auth.configure { |c| c.signing_key = "x" * 64 }
Bitsmithy::Auth.test_mode!
```

Then in tests, `send_code` always succeeds and `verify_code(phone, "000000")` always issues a decodable Token — no Twilio calls.

`test_mode!` raises `ConfigurationError` outside `Rails.env.test?` / `Rails.env.development?`, and refuses in non-Rails contexts entirely. See [`docs/adr/0002`](docs/adr/0002-test-mode-rails-env-guard.md) for why this guard is non-negotiable.

## Error vocabulary

`Result#error` is always one of:

| Symbol | Origin | Meaning |
|---|---|---|
| `:invalid_phone_number` | gem / Twilio 60200 | Phone failed normalisation, or Twilio rejected the format |
| `:invalid_code` | Twilio Verify | User typed the wrong OTP |
| `:rate_limited` | gem | Gem-side rate limiter triggered |
| `:max_send_attempts` | Twilio 60203 | Twilio's per-Phone send cap reached |
| `:max_check_attempts` | Twilio 60202 | Too many verification attempts against one code |
| `:twilio_authentication_error` | Twilio HTTP 401 | Your Twilio credentials are wrong |
| `:twilio_rate_limited` | Twilio HTTP 429 | Twilio is throttling the whole account |
| `:twilio_service_unavailable` | Twilio HTTP 5xx / timeout | Twilio is having an incident |
| `:twilio_error` | fallback | Unmapped Twilio error |

Exceptions you may catch directly:

| Class | When |
|---|---|
| `Bitsmithy::Auth::Error` | Base — all gem exceptions inherit |
| `Bitsmithy::Auth::ConfigurationError` | Missing required config; `test_mode!` outside Rails test/dev |
| `Bitsmithy::Auth::InvalidPhoneNumber` | `normalize_phone` couldn't parse |
| `Bitsmithy::Auth::InvalidToken` | `decode_token` failed signature / expiry / issuer |
| `Bitsmithy::Auth::RateLimited` | Internal — converted to `Result.failure(:rate_limited)` before host apps see it |

## PII redaction

Phone numbers are PII. The gem ships `Bitsmithy::Auth.redact_phone` for use in your own log statements:

```ruby
Rails.logger.info("Sent code to #{Bitsmithy::Auth.redact_phone(phone)}")
# => "Sent code to +1******1234"
```

The masking rule: keep the leading `+` and country code, mask the middle with `*`, keep the trailing four digits.

`Result#phone` carries the unredacted normalised Phone — the success path needs it to write to your User table. **Don't log `Result` objects raw** — use `redact_phone(result.phone)` instead. See [`docs/adr/0004`](docs/adr/0004-redact-phones-in-exceptions.md) for the nuance about when redaction applies.

## Multi-language portfolio

This gem is the reference implementation of bitsmithy-auth. Sibling implementations follow the same wire contract — Phone (E.164), Token (HS256 JWT with `iss: "bitsmithy-auth"`), error symbols, Identity shape:

- `bitsmithy/auth-ruby` (this gem)
- `bitsmithy/auth-python` *(planned)*
- `bitsmithy/auth-go` *(planned)*

A Token issued by any of the three validates in any of the three, provided they share `signing_key` and Twilio Verify Service SID. See [`docs/adr/0006`](docs/adr/0006-pattern-a-cross-language-naming.md) for the naming convention.

## Pointers

- [`CONTEXT.md`](CONTEXT.md) — domain glossary (12 terms)
- [`docs/adr/`](docs/adr/) — six Architectural Decision Records
- [`docs/claude/`](docs/claude/) — PRD, tasks, and implementation history

## Development

```bash
bin/setup           # bundle install
bundle exec rake    # tests + Rubocop
bin/console         # IRB with the gem loaded
```

## License

MIT. See [`LICENSE.txt`](LICENSE.txt).
