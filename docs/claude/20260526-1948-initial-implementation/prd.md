# bitsmithy-auth v0.1.0 — PRD

## Problem Statement

Across the bitsmithy portfolio of personal Ruby projects, every application that wants phone-number sign-in reimplements the same plumbing: a verifications table, an OTP generator with expiry and attempt counts, rate-limit logic, a Twilio integration, a sessions controller, JWT or session encoding, and phone normalization. Each implementation drifts from the others over time. Each independently has to worry about SMS pumping fraud, which is a known abuse pattern that Twilio Verify exists to mitigate. Maintaining three flavours of this code across three apps — and prospectively across three languages — is both unfun and lower-quality than centralising it once.

## Solution

`bitsmithy-auth` is a private Ruby gem that exposes Phone-number Verification as a primitive — and only as a primitive (per ADR-0003). A Host app configures the gem once with Twilio Verify credentials and a Signing key, then calls `send_code` and `verify_code` to drive the OTP dance. On success the gem hands back a Token; the Host app stores it (typically in its Rails session), then reads `current_phone` from the Controller concern on subsequent requests. The gem does not own a User concept, a sessions table, a phone-change flow, or a revocation list. Host apps build those on top.

The gem is the first of three sibling implementations (`bitsmithy/auth-ruby`, `bitsmithy/auth-python`, `bitsmithy/auth-go`); its semantics define the contract the others will mirror. See ADR-0006 for the cross-language naming convention.

## User Stories

### Host-app developer — integration

1. As a Host app developer, I want to configure the gem in a single initializer with Twilio credentials, a Verify Service SID, and a Signing key, so that the gem is ready to use across the whole application after one configuration block.
2. As a Host app developer, I want a clear failure at boot if any required configuration is missing, so that I do not discover the problem at the moment a real user is trying to sign in.
3. As a Host app developer, I want `send_code` to accept a phone number in any plausible human format ("(555) 555-1234", "+1 555 555 1234", "555.555.1234") and normalize it to E.164 internally, so that I never have to write input cleanup in my own controller.
4. As a Host app developer, I want `send_code` and `verify_code` to return a Result rather than raising on expected failures (wrong code, rate-limited, Twilio outage), so that my controller flow stays branchable and easy to read.
5. As a Host app developer, I want `decode_token` to raise on tampered or expired Tokens, so that I do not have to write `nil`-checks at every read site — a bad Token is a bug or an attack, not a normal flow.
6. As a Host app developer, I want a tiny Rails Controller concern that exposes `current_phone`, `current_identity`, `authenticated?`, `sign_in`, and `sign_out`, so that my controllers can ask "who is this user?" without knowing about JWTs or sessions directly.
7. As a Host app developer, I want to own the unauthenticated-redirect decision myself (no `require_authentication!` helper baked into the gem), so that one app can return a JSON 401 while another redirects to `/sign_in` without fighting the gem.
8. As a Host app developer, I want to use the gem from non-Rails code (a Rake task, a CLI, a Sidekiq job that needs to issue a Token), so that the core API does not require Rails to be loaded.
9. As a Host app developer, I want the same Identity contract across the Ruby, Python, and Go implementations of bitsmithy-auth, so that my multi-language stack reads the same Token everywhere.

### Host-app developer — error handling

10. As a Host app developer, I want Twilio failures categorised into four distinct symbols (`:twilio_authentication_error`, `:twilio_rate_limited`, `:twilio_service_unavailable`, `:twilio_error`) rather than one opaque bucket, so that I can page my oncall on authentication errors while showing users a "try again" message for service outages.
11. As a Host app developer, I want `:invalid_phone_number` returned for unparseable phone input, so that I can render a friendly form error rather than crashing.
12. As a Host app developer, I want `:invalid_code` returned when the user types the wrong OTP, so that I can render the verification screen again with an inline error.
13. As a Host app developer, I want `:rate_limited` returned when too many `send_code` calls have hit the same Phone in the configured window, so that I can render a "please wait" message rather than burn Twilio budget.

### End user — verification flow (via the Host app)

14. As an end user, I want to enter my phone number and receive an SMS code, so that I can prove I control that phone.
15. As an end user, I want my phone number to be accepted whether I type it with spaces, parentheses, dashes, dots, or in raw E.164, so that I am not gated on formatting nitpicks.
16. As an end user, I want a clear "please wait" response if I have requested too many codes too quickly, so that I understand why nothing is being sent.
17. As an end user, I want to enter the six-digit code and be signed in, so that I can use the Host app immediately.
18. As an end user, I want a wrong-code attempt to fail clearly and let me retry, so that I can correct a typo without starting over.
19. As an end user, I want to stay signed in for ~24 hours without re-verifying, so that the friction of the Verification flow is bounded.

### Operator — running this in production

20. As an Operator, I want the gem's exception messages to redact Phones to a masked form (`+1******1234`) before reaching my error tracker, so that PII does not get indexed in Sentry or Honeybadger logs (per ADR-0004).
21. As an Operator, I want a public `redact_phone` helper exported by the gem, so that I can apply the same redaction inside my own log statements without rolling my own.
22. As an Operator, I want a default per-Phone Rate limit (5 sends per hour) applied before the gem ever calls Twilio, so that I do not have to discover Twilio's bill at the end of the month after an abuse incident.
23. As an Operator, I want the Rate limiter's backing Store to be pluggable, so that when one of my apps outgrows single-process state I can drop in a Redis-backed store without changing the rest of the gem.
24. As an Operator, I want rotating the Signing key to be a viable operation (with the consequence that all existing Tokens become invalid), so that I have a recovery path when a key leaks.
25. As an Operator, I want stateless Tokens (per ADR-0001) so that authenticated request handling never touches a runtime store on the hot path.
26. As an Operator, I want `test_mode!` to refuse to run in production-like Rails environments and refuse to run outside Rails entirely (per ADR-0002), so that I cannot footgun myself into "anyone can sign in as anyone by typing 000000" on a live system.
27. As an Operator, I want the gem to never log a Phone itself — any logging is the Host app's choice via the `redact_phone` helper, so that the logging-pipeline contract is owned by the Host app.

### Test author — writing tests for a Host app

28. As a test author for a Host app, I want a Test mode that swaps the OTP adapter so my controller and feature tests can run without hitting Twilio's network, so that my CI does not flake on third-party outages and does not need real Twilio credentials.
29. As a test author, I want a single magic OTP (`"000000"`) that always verifies in Test mode, so that my sign-in feature tests are concise and predictable.
30. As a test author, I want Test mode `send_code` to always succeed, so that I can drive the Verification flow without inspecting Twilio API mocks.

### Maintainer — gem itself

31. As a maintainer of `bitsmithy-auth`, I want the gem's internal OTP::Adapter interface to be small enough that a `VonageAdapter` or `MessageBirdAdapter` could ship as a separate gem without breaking the public surface, so that we are not strictly locked into Twilio even though we are commercially betting on it (per ADR-0005).
32. As a maintainer, I want the gem's Rails Controller concern conditionally loaded only when `ActionController` is defined, so that non-Rails Host apps incur zero Rails-related require cost.
33. As a maintainer, I want every public module method documented with a happy-path test and at least one failure-path test, so that the API contract is enforced by tests rather than by comments.

## Implementation Decisions

### Modules

The gem decomposes into eight modules, grouped by layer.

**Core API (framework-agnostic):**

1. **Phone** — a deep module exposing one method, `normalize(input, country:)`, that returns an E.164 string or raises `InvalidPhoneNumber`. Wraps phonelib internally. The raised exception's message uses a redacted form of the input.
2. **Token** — a deep module exposing `encode(phone:, config:)` returning a JWT string, and `decode(token, config:)` returning an Identity or raising `InvalidToken`. The Token carries `sub` (Phone), `iat`, `exp`, and `iss: "bitsmithy-auth"`; `decode` verifies the issuer claim. HS256 only.
3. **OTP::Adapter** — interface contract: `send_code(phone) → Result`, `verify_code(phone, code) → Result`. Two implementations:
   - **OTP::TwilioAdapter** — wraps Twilio Verify. Maps known Twilio error codes into one of four Result error symbols: `:twilio_authentication_error` (Twilio 401), `:twilio_rate_limited` (Twilio 429), `:twilio_service_unavailable` (Twilio 5xx, timeouts), `:twilio_error` (anything else not mapped to a more specific symbol like `:invalid_phone_number` or `:max_check_attempts`). Specific Twilio Verify error codes (60200, 60202, 60203) map to phone-specific symbols.
   - **OTP::TestAdapter** — never touches the network. `send_code` always succeeds; `verify_code` succeeds only when `code == "000000"`.
4. **RateLimiter** — a deep module exposing `check!(key)` that consults the configured Store and raises `RateLimited` when the count for `key` within the configured window exceeds the configured max.
5. **Stores::MemoryStore** — the default Store. Implements `increment(key, window_seconds) → count` with mutex-protected sliding-window state. Pluggable: any object responding to `increment` is a valid Store.
6. **Config** — a shallow data holder with `validate!` raising `ConfigurationError` if any of `twilio_account_sid`, `twilio_auth_token`, `twilio_verify_service_sid`, `signing_key` is unset. Defaults: `session_duration` 24 hours (per ADR-0001), `rate_limit` 5 per Phone per hour. Holds references to the active OTP adapter and Rate-limit Store; both default to lazy-initialized instances if the Host app does not provide their own.
7. **Bitsmithy::Auth (top-level)** — the public façade. Exposes `configure { |c| ... }`, `send_code(phone)`, `verify_code(phone, code)`, `decode_token(token)`, `normalize_phone(input, country:)`, `test_mode!`, `redact_phone(phone)`, and `reset_config!` (for tests). Composes the other modules. `send_code` rate-limits before calling the OTP adapter and converts both `InvalidPhoneNumber` and `RateLimited` into failure Results.

**Rails integration (optional, conditionally loaded):**

8. **Bitsmithy::Auth::Controller** — a Rails concern providing `current_phone`, `current_identity`, `authenticated?`, `sign_in(phone:, token:)`, and `sign_out`. Reads from and writes to `session[:bitsmithy_auth_token]`. Memoizes the decoded Identity per request; invalidates the memo on `sign_in`/`sign_out`. Deliberately does NOT include a `require_authentication!` helper — Host apps own redirect semantics. Loaded only when the `ActionController` constant is defined.

### Result and Identity shapes

- **Result** is a value object carrying `success?`, `error` (symbol or nil), `token` (String or nil), `channel` (`:sms` for v0.1.0), `phone` (the normalized E.164 form). Two factory methods: `Result.success(...)` and `Result.failure(...)`.
- **Identity** is a value object carrying `phone` (E.164 String), `issued_at` (Time), `expires_at` (Time). Constructed only by `Token.decode`.

Both are Ruby 3.2+ `Data` classes — immutable, structural.

### Result-vs-raise convention

- `send_code`, `verify_code` → return Result. Expected user-input failures are normal flow.
- `decode_token`, `normalize_phone` → raise. Their failure modes (tampered Token, garbage Phone input) are programmer error or attack — exceptions match the right ergonomics.
- `configure` → raises `ConfigurationError` from `validate!` if required fields are missing. Boot-time failure.
- `test_mode!` → raises `ConfigurationError` if the Rails-env guard rejects (per ADR-0002). Misuse is a developer error.

### Error-symbol vocabulary (for Result#error)

The exhaustive list of error symbols a Result can carry:

- `:invalid_phone_number` — phone failed normalization, OR Twilio returned 60200
- `:invalid_code` — Twilio Verify check was not approved
- `:rate_limited` — gem-side Rate limiter triggered
- `:max_send_attempts` — Twilio 60203 (per-phone send cap on Twilio's side)
- `:max_check_attempts` — Twilio 60202 (per-code check cap on Twilio's side)
- `:twilio_authentication_error` — Twilio 401 (Host app's Twilio credentials are wrong)
- `:twilio_rate_limited` — Twilio 429 (Twilio is throttling the whole account)
- `:twilio_service_unavailable` — Twilio 5xx or timeout
- `:twilio_error` — fallback for unmapped Twilio errors

### Token shape

- Algorithm: HS256, signed with `config.signing_key`. No other algorithms supported in v0.1.0.
- Claims: `sub` = normalized E.164 Phone, `iat` = now, `exp` = now + `session_duration`, `iss` = `"bitsmithy-auth"`.
- `decode` verifies signature, expiry, and `iss` claim. Failures collapse into `InvalidToken` with a generic message (does NOT echo the bad Token).

### Test mode mechanics

- `test_mode!` swaps `config.otp_adapter` to a new `TestAdapter` instance.
- If `config.signing_key` is unset at the moment `test_mode!` is called, the gem auto-fills it with the literal string `"test-signing-key-not-for-production"` so test-suite tests can encode/decode without explicit setup. Production code paths that called `validate!` first will not reach this branch because `validate!` would have already raised.
- Environment guard: raises `ConfigurationError` unless `defined?(Rails) && (Rails.env.test? || Rails.env.development?)` (per ADR-0002).
- Magic code: `"000000"` always verifies in Test mode.

### PII redaction

- `Bitsmithy::Auth.redact_phone(phone)` is a public helper returning a masked form: keep the country code prefix (`+1`) and the last four digits, replace the middle with asterisks. Example: `"+15555551234"` → `"+1******1234"`.
- `InvalidPhoneNumber#message` includes the redacted form of the input that failed parsing, never the raw input.
- `Result#phone` carries the un-redacted normalized Phone (Host apps need this to render "code sent to +1..1234" or to write to their own database). Logging `Result` raw will leak the Phone — the README will tell Host apps to use `redact_phone(result.phone)` in any log statement.

### Rate limit

- Default: 5 sends per Phone per hour. Configurable via `config.rate_limit = { per_phone: N, window: seconds }`.
- Rate-limit key is namespaced (`"send_code:#{normalized_phone}"`) so future verbs (if added) get their own bucket.
- The check happens **before** the OTP adapter is called, so Twilio is not billed for rate-limited attempts.
- Default Store is `Stores::MemoryStore`. Multi-worker Rails Host apps will get per-worker counters with this default — accepted trade-off in v0.1.0; documented; Redis Store is a v0.2.0 deliverable.

### Conditional loading

- `lib/bitsmithy/auth.rb` requires the core modules unconditionally. After defining the top-level surface, it conditionally requires `bitsmithy/auth/controller` if `ActionController` is defined at load time.
- The controller concern itself requires `active_support/concern`. This is safe because `ActionController` being defined implies `ActiveSupport` is loaded.

### ADR pointers

- Stateless Tokens with no revocation: ADR-0001.
- Test mode environment guard: ADR-0002.
- Verification primitive, not user system: ADR-0003.
- Phone redaction in exceptions: ADR-0004.
- Twilio Verify as OTP backend: ADR-0005.
- Pattern A cross-language naming: ADR-0006.

## Testing Decisions

### What makes a good test in this codebase

Per the `testing.md` rules:
- TDD by default: every test is written before the implementation it covers (RED → GREEN → REFACTOR).
- Test behaviour, not implementation. No assertions against private state or method names; assert on the observable surface (return value, raised exception, Result fields, session contents).
- One assertion per test where possible. Multiple assertions only when they verify the same behaviour from slightly different angles.
- Sentence-style names: `test_normalize_returns_e164_for_us_number_when_country_is_us`, not `test_normalize_1`.
- Tests must run in isolation and in any order; shared state lives in a `ConfigHelper` module that resets the gem's config in `setup`.
- Maximize shared setup at the test-file level; each test applies the minimum mutation it needs.

### Which modules are tested

Every module identified in the module sketch gets a unit-test file, plus an integration-style file for the top-level `Bitsmithy::Auth` façade. Specifically:

- **Phone** — happy paths across format variations, raise paths for ambiguous and garbage input, raise messages confirmed to use the redacted form.
- **Token** — encode produces a parseable JWT with correct claims; decode round-trips an Identity; decode raises `InvalidToken` for garbage, wrong signing key, expired token, and wrong issuer.
- **Config** — defaults assert; `validate!` raises for each missing required field; passes when all are set.
- **Result** — `Result.success` and `Result.failure` factories produce expected shapes; `success?` reflects the flag.
- **RateLimiter** — check passes under the threshold; raises at the boundary; isolates per-key state.
- **Stores::MemoryStore** — increment counts within the window; resets after the window; isolates per-key; explicit `reset` clears all.
- **OTP::TestAdapter** — `send_code` always succeeds; `verify_code` succeeds only for `"000000"`; failure path returns `:invalid_code`.
- **OTP::TwilioAdapter** — uses Mocha to stub the Twilio client chain. Asserts the correct chain methods are called with the right arguments; asserts the four error-symbol categorisations; asserts success returns a Token-bearing Result.
- **Bitsmithy::Auth (top-level)** — `configure` yields a Config; `test_mode!` swaps the adapter; `send_code` normalises Phone before delegating; rate-limit failure surfaces as `:rate_limited` Result; invalid Phone surfaces as `:invalid_phone_number` Result; `decode_token` delegates correctly; `normalize_phone` delegates correctly.
- **Bitsmithy::Auth::Controller** — tested via a minimal fake controller class that includes the concern and exposes a `session` hash. Covers happy and unhappy paths for `current_phone`, `current_identity`, `authenticated?`, and the memoisation behaviour of `sign_in`/`sign_out`.

### Test-stack choices

- Minitest (per the gem scaffold).
- Mocha for stubbing the Twilio SDK in `OTP::TwilioAdapter` tests. WebMock is intentionally not used.
- `actionpack` is added in the `:test` group of the Gemfile so the Controller concern's tests can rely on the `ActionController` constant being defined.

### Prior art in this codebase

None yet — this is the first feature. The scaffold-generated `test/bitsmithy/test_auth.rb` containing only the version assertion is the seed pattern. Subsequent tests follow the nested-module style (`module Bitsmithy; module Auth; class TestX < Minitest::Test`) to satisfy Rubocop's `Style/ClassAndModuleChildren: nested`.

### Coverage target

Every public method gets at least one happy-path test and at least one failure-path test. There is no percentage target; we are aiming for behavioural completeness, not line coverage.

## Out of Scope

The following are deliberate exclusions from v0.1.0. Each has a reason; "we ran out of time" is not one of them.

- **Mountable Rails engine** with default sign-in views — deferred to v0.2.0. The right shared UI is unknown until the gem has been used in 2–3 Host apps. Each app writes a ~30-line `SessionsController` of its own for v0.1.0.
- **Install generator** (`rails g bitsmithy:auth:install`) — pairs with the engine; same reasoning.
- **Default ERB views** — pairs with the engine.
- **Redis-backed Rate-limit Store** — interface is in place (`Store#increment(key, window) → count`); a concrete `RedisStore` is a v0.2.0 deliverable when the first multi-worker production deployment of a Host app needs it.
- **Voice channel OTP** and **WhatsApp channel OTP** — Twilio Verify supports both; the gem hardcodes `channel: "sms"` in v0.1.0. Extending later is a one-symbol addition.
- **Per-Host-app SMS template overrides from inside the gem** — Twilio Verify Services already support per-service templates configured Twilio-side. There is no value in re-exposing this through the gem.
- **Email OTP**, **TOTP**, **authenticator-app codes** — Phone-only is the v0.1.0 scope. If we ever add these they will likely go in a different gem rather than swelling this one.
- **Signing-key rotation with overlap window** — single key, rotation invalidates all existing Tokens. Documented as a deliberate non-feature (per ADR-0001).
- **Hard token revocation** ("kick this user out NOW") — Host-app concern (per ADR-0001 and ADR-0003). Pattern documented in ADR-0001.
- **Phone-number-change primitives** — Host-app concern. Implemented by running the gem's normal Verification flow against the new Phone and updating Host-app state.
- **A `Bitsmithy::Auth::User` model**, sessions table, or any state owned by the gem beyond Config-time settings — see ADR-0003 for why this stays out forever.
- **`require_authentication!` Controller helper** — Host apps own redirect semantics, so the gem does not encode a single answer.
- **Automatic log scrubbing** (e.g. a Lograge filter shipped by the gem) — the `redact_phone` helper is enough; Host apps wire it where they want it.

## Further Notes

- This gem is the reference implementation of the bitsmithy-auth contract. `bitsmithy/auth-python` and `bitsmithy/auth-go` will mirror its public semantics (the verbs, the error symbols, the Identity shape, the Token claim structure). Decisions taken here are binding on those repos.
- The gem will be consumed via `gem 'bitsmithy-auth', github: 'bitsmithy/auth-ruby'` Gemfile entries — no publishing to rubygems.org. The gemspec's `allowed_push_host` is intentionally left commented out (configurable later if GitHub Packages or a private registry is adopted).
- The gem deliberately has no opinion on persistence. A Host app integrating it does not need to add any migrations. The only persistent state introduced is whatever the Host app chooses to do with the verified Phone (typically a `users.phone` column).
- The `signing_key` should be generated with at least 32 bytes of entropy. The README will tell Host apps to run `SecureRandom.hex(32)` and store the result in their secrets manager.
- The default `session_duration` of 24 hours is overridable per Host app. Apps that want a different blast-radius/friction trade-off (e.g. an admin tool wanting 1 hour, a marketing site wanting 7 days) can set it during `configure`.
