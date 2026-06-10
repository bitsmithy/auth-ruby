# bitsmithy-auth

Phone-number OTP authentication for Ruby applications. Verify a user by sending them an SMS code; receive a signed Token in return; decode it into an Identity.

This gem is a **verification primitive**, not a user-management system. It does not own a User model, a sessions table, or a phone-change flow. Host apps map verified Phones to their own user records however they want. See [`docs/adr/0003`](docs/adr/0003-verification-primitive-not-user-system.md) for the rationale.

Backed by [Twilio Verify](https://www.twilio.com/docs/verify) — Twilio owns OTP generation, expiry, attempt limits, and SMS-pumping fraud detection. We never store an OTP locally.

## Status — v0.1.0

| Shipped |
|---|
| Framework-agnostic core API |
| Rails `Controller` concern (optional) |
| Twilio Verify production adapter |
| Per-Phone rate limiting (in-memory store) |
| PII-redacting `redact_phone` helper |
| `test_mode!` with Rails-env guard |
| Mountable Rails engine (no shipped views) |
| Opt-in `require_authentication!` guard |
| Shipped `en` locale for error messages |

### Future (not yet shipped)

Install generator, Redis-backed rate-limit store, voice / WhatsApp channels, email OTP / TOTP.

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
| `require_authentication!` | Redirects to the configured sign-in path (default the Engine's sign-in route) if not authenticated — see [Engine](#mountable-engine) below. Opt-in per controller: `before_action :require_authentication!` |

`require_authentication!` is the opt-in guard. Add it to any controller (or your `ApplicationController`) with a single `before_action` — it is never auto-applied.

## Mountable engine

When `Rails::Engine` is available (Rails app with `railties`), the gem ships `Bitsmithy::Auth::Engine` — a mountable Rails engine that owns the entire sign-in flow.

### One-line mount

```ruby
# config/routes.rb
Rails.application.routes.draw do
  mount Bitsmithy::Auth::Engine => "/auth"
end
```

This gives you these routes:

| Method | Path | Engine action | Named helper |
|---|---|---|---|
| GET | `/auth/sign_in` | `sessions#new` | `sign_in_path` |
| POST | `/auth/send_code` | `sessions#create` | `send_code_path` |
| GET | `/auth/code` | `sessions#edit` | `code_path` |
| POST | `/auth/verify` | `sessions#update` | `verify_path` |
| DELETE | `/auth/sign_out` | `sessions#destroy` | `sign_out_path` |

### Required templates

The engine **ships no views** (ADR-0008). Your app must provide two templates:

**`app/views/bitsmithy/auth/sessions/new.html.erb`** — Phone-entry form.

| Local / helper | Description |
|---|---|
| `@error` | Error message string when re-rendered after a failure (nil on first load) |
| `send_code_path` | Named route helper for the send step (POST) |

**`app/views/bitsmithy/auth/sessions/edit.html.erb`** — Code-entry form.

| Local / helper | Description |
|---|---|
| `@phone` | The pending Phone (E.164 string) stored from the send step |
| `@error` | Error message string when re-rendered after a failure (nil on first load) |
| `verify_path` | Named route helper for the verify step (POST) |

### Configuration

Configure the engine in the same initializer you already use:

```ruby
# config/initializers/bitsmithy_auth.rb
Bitsmithy::Auth.configure do |c|
  c.signing_key               = ENV.fetch("BITSMITHY_AUTH_SIGNING_KEY")
  c.twilio_account_sid        = ENV.fetch("TWILIO_ACCOUNT_SID")
  c.twilio_auth_token         = ENV.fetch("TWILIO_AUTH_TOKEN")
  c.twilio_verify_service_sid = ENV.fetch("TWILIO_VERIFY_SERVICE_SID")
  c.otp_adapter               = Bitsmithy::Auth::OTP::TwilioAdapter.new(c)

  # Optional overrides (defaults shown):
  # c.session_duration = 86_400
  # c.after_sign_in_path  = "/"
  # c.after_sign_out_path = "/"
  # c.on_verified         = ->(identity) { ... }
end
```

| Config | Default | Description |
|---|---|---|
| `after_sign_in_path` | `"/"` | Where to redirect after successful verification |
| `after_sign_out_path` | `"/"` | Where to redirect after sign-out |
| `sign_in_path` | Engine's sign-in route (`/auth/sign_in` when mounted at `/auth`) | Redirect target for `require_authentication!` — can be overridden by host |
| `on_verified` | `nil` | Optional callback invoked with the verified Identity on successful verification |

### Using `require_authentication!`

The engine Controller concern provides an opt-in `require_authentication!` guard. Add it to any controller to protect actions:

```ruby
class ApplicationController < ActionController::Base
  include Bitsmithy::Auth::Controller
  before_action :require_authentication!
end
```

Unauthenticated requests are redirected to the configured `sign_in_path` (default: the engine's sign-in route). The engine's own controller skips this guard so the sign-in flow stays accessible.

### Mapping the verified Identity downstream

After a successful sign-in, `current_identity` returns the decoded Identity. Map the verified phone to your own user records wherever you need it:

```ruby
# app/controllers/application_controller.rb
def current_user
  return unless current_identity

  @current_user ||= User.find_or_create_by!(phone: current_identity.phone)
end
```

The engine never owns a User model — you decide what a verified phone means.

## Test mode

```ruby
# test_helper.rb / spec_helper.rb
Bitsmithy::Auth.configure { |c| c.signing_key = "x" * 64 }
Bitsmithy::Auth.test_mode!
```

Then in tests, `send_code` always succeeds and `verify_code(phone, "000000")` always issues a decodable Token — no Twilio calls.

`test_mode!` raises `ConfigurationError` outside `Rails.env.test?` / `Rails.env.development?`, and refuses in non-Rails contexts entirely. See [`docs/adr/0002`](docs/adr/0002-test-mode-rails-env-guard.md) for why this guard is non-negotiable.

## Error vocabulary

Error messages for the engine-flow symbols (`invalid_phone_number`, `rate_limited`, `invalid_code`) are shipped in the `en` locale under `bitsmithy_auth.errors.<symbol>`. Host apps override by defining the same keys in their own locale files. See also the [Mountable engine](#mountable-engine) section.

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
