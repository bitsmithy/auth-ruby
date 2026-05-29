## [Unreleased]

## [0.1.0] - 2026-05-28

Initial release. Phone-number OTP authentication primitive for Ruby applications.

### Added

- **Core verification API** on `Bitsmithy::Auth`: `configure`, `send_code`,
  `verify_code`, `decode_token`, `normalize_phone`, `redact_phone`, `test_mode!`,
  `reset_config!`. Result-returning methods for expected user-input failures;
  raising methods for tampering / programmer error.
- **Twilio Verify** as the production OTP backend (`OTP::TwilioAdapter`).
  Maps Twilio Verify error codes 60200/60202/60203 and HTTP status 401/429/5xx
  into nine documented Result error symbols.
- **Test mode** (`OTP::TestAdapter`) — `send_code` always succeeds and
  `verify_code(phone, "000000")` always issues a valid Token. Guarded by an
  ADR-mandated Rails-environment check; refuses to enable in production or
  outside Rails entirely.
- **Per-Phone rate limiting** — gem-side `RateLimiter` sits in front of the
  OTP adapter so Twilio is never billed for rate-limited attempts. Defaults
  to 5 sends per Phone per hour. Pluggable Store interface; ships an
  in-memory mutex-protected `Stores::MemoryStore` as the default.
- **HS256 JWT tokens** with `sub`, `iat`, `exp`, and `iss: "bitsmithy-auth"`
  claims. Issuer is verified on decode. Default `session_duration` is 24h.
- **Rails Controller concern** (`Bitsmithy::Auth::Controller`) — conditionally
  loaded only when `ActionController` is defined. Exposes `current_phone`,
  `current_identity`, `authenticated?`, `sign_in(token:)`, and `sign_out`.
  Deliberately omits `require_authentication!` — host apps own redirect
  semantics.
- **PII redaction** — `Bitsmithy::Auth.redact_phone` public helper that masks
  the middle digits of an E.164 number for safe inclusion in log statements.
- **Phone normalisation** via `phonelib` (libphonenumber).

### Architectural decisions

Six ADRs in `docs/adr/` document the load-bearing choices:

- 0001 — Stateless JWT without revocation
- 0002 — Test mode Rails-env guard
- 0003 — Verification primitive, not a user system
- 0004 — Redact phones in successful-Phone exceptions, not in failed-parse inputs
- 0005 — Twilio Verify as OTP backend
- 0006 — Pattern A cross-language naming convention

### Not in v0.1.0 (planned for v0.2.0+)

Mountable Rails engine with default sign-in views; install generator;
Redis-backed rate-limit Store; voice / WhatsApp OTP channels; email OTP;
TOTP / authenticator-app codes.
