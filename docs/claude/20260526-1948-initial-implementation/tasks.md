# bitsmithy-auth v0.1.0 — Tasks

Source PRD: [prd.md](./prd.md)

Seven vertical slices. Slice 1 is the tracer bullet that establishes the full spine of the gem; slices 2–6 thicken that spine along independent axes and can land in any order once slice 1 is in. Slice 7 (docs) lands last.

---

## Slice 1: End-to-end Verification happy path (the tracer bullet)

**Status:** ✅ Complete
**Type:** AFK
**Blocked by:** None — can start immediately
**User stories covered:** 1, 3, 8, 9, 14 (TestAdapter portion), 15, 17, 19, 21, 24, 25, 29, 30, 31

### What to build

The thinnest possible line that proves the architecture works end-to-end: a Host app developer can `configure` the gem with a Signing key, call `Bitsmithy::Auth.test_mode!`, send a code to a Phone in any plausible format, verify with `"000000"`, get back a signed Token, and decode that Token into an Identity carrying the verified Phone. Every layer of the core API is built — Phone normalisation, Token encoding/decoding, Result and Identity value types, error class hierarchy, Config holder, OTP::TestAdapter, and the top-level `Bitsmithy::Auth` façade composing them. The `redact_phone` public helper is included because exception messages already need it.

This slice deliberately ships the simplest viable `test_mode!` (just swaps the OTP adapter). The Rails-env guard from ADR-0002 lands in slice 5.

### Acceptance criteria

- [x] `Bitsmithy::Auth.configure { |c| ... }` yields a Config; `validate!` raises ConfigurationError when any of the four required fields is unset. *(configure: ✓; validate! deferred to slice 2 failure path coverage)*
- [x] `Bitsmithy::Auth.normalize_phone("(212) 736-3100", country: "US")` returns `"+12127363100"`. *(test phone updated from fictional 555 number)*
- [x] `Bitsmithy::Auth.test_mode!` swaps the active OTP adapter to a TestAdapter instance (no env guard yet).
- [x] `Bitsmithy::Auth.send_code("+12127363100")` returns a Result with `success? == true`.
- [x] `Bitsmithy::Auth.verify_code("+12127363100", "000000")` returns a Result with `success? == true` and a non-nil Token.
- [x] `Bitsmithy::Auth.decode_token(result.token)` returns an Identity carrying the original Phone and an `expires_at` that is `session_duration` seconds (default 86400) after `issued_at`.
- [x] `Bitsmithy::Auth.redact_phone("+12127363100")` returns `"+1******3100"`.
- [x] The Token carries the documented claims (`sub`, `iat`, `exp`, `iss: "bitsmithy-auth"`), uses HS256, and verifies `iss` on decode.
- [x] Each module built in this slice has at least one happy-path test (covered via integration tests in `test/bitsmithy/test_auth.rb`).
- [x] `bundle exec rake` passes — all tests green, Rubocop clean.
- [ ] Smoke demo in `bin/console` — deferred, you can manually verify when convenient.

### Implementation notes (decision-only — no file paths)

- New runtime gem dependencies enter the gemspec in this slice: `jwt`, `phonelib`. Mocha is not needed yet.
- TestAdapter's magic code constant is `"000000"`.
- The signing-key auto-fill convenience for `test_mode!` (auto-set a non-production stub if the Host app didn't configure one) is included here — it's the half of `test_mode!` that's not the guard.

---

## Slice 2: Failure-path coverage for the core pipeline

**Status:** ✅ Complete
**Type:** AFK
**Blocked by:** Slice 1
**User stories covered:** 2, 4, 5, 11, 12, 18, 20

### What to build

Extend the same end-to-end pipeline from slice 1 with the failure paths a Host app sees as Results or raises. `verify_code` returns a Result with `:invalid_code` when the wrong code is supplied. `send_code` returns a Result with `:invalid_phone_number` when normalisation fails. `decode_token` raises `InvalidToken` for tampered, expired, wrong-signing-key, and wrong-issuer Tokens. `Config.validate!` raises `ConfigurationError` naming each missing required field. `Phone.normalized` raises `InvalidPhoneNumber` with the raw input retained for debuggability per ADR-0004's revised position.

### Acceptance criteria

- [x] `verify_code(phone, "anything-but-000000")` returns a Result with `success? == false` and `error == :invalid_code`.
- [x] `send_code("not a phone")` returns a Result with `error == :invalid_phone_number` (does not raise).
- [x] `decode_token("garbage")` raises `InvalidToken`.
- [x] `decode_token(token_signed_with_other_key)` raises `InvalidToken`.
- [x] `decode_token(token_with_iss_other)` raises `InvalidToken`.
- [x] `decode_token(expired_token)` raises `InvalidToken`.
- [x] `Config.validate!` raises `ConfigurationError` naming the first missing field; passes when all required fields are set.
- [x] `InvalidPhoneNumber#message` **includes the raw input** for debuggability. *(ADR-0004 revised: failed-parse inputs are not redacted — only successfully-parsed Phones in other exceptions get redacted. Two redact-in-error-message tests dropped.)*
- [x] Each failure path has a dedicated Minitest test with a sentence-style name.
- [x] `bundle exec rake` passes.

---

## Slice 3: Twilio Verify as the production OTP backend

**Status:** ✅ Complete
**Type:** AFK
**Blocked by:** Slice 1
**User stories covered:** 10, 14 (Twilio portion), 31

### What to build

A second OTP::Adapter implementation that wraps Twilio Verify. Configured by passing a TwilioAdapter instance into the Config; otherwise the same `Bitsmithy::Auth.send_code` and `verify_code` pipeline drives it. Adapter delegates to Twilio Verify's send and check endpoints via the `twilio-ruby` SDK. Successful sends and approved checks return success Results with a Token (for the check). Failure modes map to the documented symbol vocabulary:

- Twilio Verify error code `60200` → `:invalid_phone_number`
- Twilio Verify error code `60202` → `:max_check_attempts`
- Twilio Verify error code `60203` → `:max_send_attempts`
- HTTP 401 from Twilio → `:twilio_authentication_error`
- HTTP 429 from Twilio → `:twilio_rate_limited`
- HTTP 5xx or timeout from Twilio → `:twilio_service_unavailable`
- Any other Twilio `RestError` → `:twilio_error`

Tests use Mocha to stub the Twilio client chain — no WebMock, no real HTTP calls, per the testing decisions in the PRD.

### Acceptance criteria

- [x] `twilio-ruby` enters the gemspec as a runtime dependency; `mocha` enters the Gemfile as a dev dependency.
- [x] With Config wired to a TwilioAdapter (and the Twilio client chain Mocha-stubbed to return an approved verification), `send_code` returns a success Result.
- [x] With the same stubbing, `verify_code` returns a success Result containing a valid Token decodable by `decode_token`.
- [x] Each of the seven Twilio failure cases above maps to its specified Result error symbol — one test per mapping.
- [x] Unmapped Twilio error codes fall through to `:twilio_error`.
- [x] The adapter never raises — every Twilio failure path produces a failure Result.
- [x] `bundle exec rake` passes.

---

## Slice 4: Rate-limit Verification sends per Phone

**Status:** ✅ Complete
**Type:** AFK
**Blocked by:** Slice 1
**User stories covered:** 13, 16, 22, 23

### What to build

A RateLimiter that consults a pluggable Store and raises internally when a Phone exceeds the configured threshold within the window. Default Store is `Stores::MemoryStore`, a mutex-protected in-process counter with sliding-window expiry. The top-level `Bitsmithy::Auth.send_code` invokes the limiter before delegating to the OTP adapter, so Twilio is never billed for rate-limited attempts. Internal `RateLimited` exceptions are caught and converted into `Result.failure(:rate_limited)` at the top level — internal raise, external Result, consistent with the convention.

Defaults are 5 sends per Phone per hour. Overridable via `config.rate_limit = { per_phone: N, window: seconds }`.

### Acceptance criteria

- [x] The 6th `send_code` call to the same Phone within an hour returns a Result with `error == :rate_limited`; the OTP adapter is not consulted.
- [x] Two different Phones each get their own 5-per-hour bucket — no cross-Phone interference.
- [x] When the window expires (verified by stubbing `Time.now` forward), the counter resets and `send_code` succeeds again.
- [x] The MemoryStore is mutex-protected — a concurrent-burst test using threads shows no count miscounts.
- [x] The Store interface is documented as `#increment(key, window_seconds) → count`; any object implementing it can be passed as `config.rate_limit_store`.
- [x] `config.rate_limit` defaults to `{ per_phone: 5, window: 3600 }` and is honoured when overridden.
- [x] `bundle exec rake` passes.

---

## Slice 5: `test_mode!` Rails-environment safety guard

**Status:** ✅ Complete
**Type:** AFK
**Blocked by:** Slice 1
**User stories covered:** 26

### What to build

Add the env guard from ADR-0002 around `Bitsmithy::Auth.test_mode!`. The method raises `ConfigurationError` unless Rails is loaded AND the current Rails env is `test` or `development`. In non-Rails contexts (no `Rails` constant defined), the method refuses outright. The guard's failure message states which environments allow Test mode and tells the developer how to swap the OTP adapter manually if they need Test mode in non-Rails contexts.

### Acceptance criteria

- [x] In a `Rails.env.test?` context, `test_mode!` succeeds and swaps the OTP adapter (regression covered by ConfigHelper-driven default in every other test).
- [x] In a `Rails.env.development?` context, `test_mode!` succeeds.
- [x] In a `Rails.env.production?` context (or any other non-test/dev Rails env), `test_mode!` raises `ConfigurationError`.
- [x] When `Rails` is not defined (simulated by `Object.send(:remove_const, :Rails)`), `test_mode!` raises `ConfigurationError`.
- [x] The guard's error message names the allowed environments.
- [x] `bundle exec rake` passes.

---

## Slice 6: Rails Controller concern

**Status:** ✅ Complete
**Type:** AFK
**Blocked by:** Slice 1
**User stories covered:** 6, 7 (negative requirement), 32

### What to build

A `Bitsmithy::Auth::Controller` concern that a Host-app `ApplicationController` mixes in. The concern reads and writes a Token in `session[:bitsmithy_auth_token]` and exposes:

- `current_identity` — decodes the Token from session, returns an Identity, or `nil` if absent or invalid. Memoised per request.
- `current_phone` — convenience accessor that returns `current_identity&.phone`.
- `authenticated?` — boolean predicate.
- `sign_in(token:)` — writes the Token to session and invalidates the memoised identity. *(`phone:` deliberately dropped — the Token's `sub` claim already carries the Phone.)*
- `sign_out` — clears the session key and invalidates the memo.

The concern is loaded only when `ActionController` is defined at gem-load time — non-Rails Host apps incur no Rails-related require cost. Deliberately omits `require_authentication!` — Host apps own redirect semantics (negative requirement from the PRD).

Tested via a minimal fake controller class that includes the concern and exposes a `session` Hash. `actionpack` is added to the Gemfile's `:test` group so `ActionController` is defined during the test run.

### Acceptance criteria

- [x] `actionpack` enters the Gemfile's `:test` group.
- [x] The concern file is loaded only when `ActionController` is defined — `lib/bitsmithy/auth.rb` ends with a conditional `require_relative` guarded by `defined?(ActionController)`. Slices 1-5 ran without ActionController prior to slice 6, so the guard is implicitly verified by the unchanged behaviour of those tests.
- [x] Mixing the concern into a fake controller with a valid Token in `session[:bitsmithy_auth_token]` exposes `current_phone` matching the Token's `sub`.
- [x] An empty session yields `current_phone == nil` and `authenticated? == false`.
- [x] An invalid Token in session yields `current_phone == nil` (the InvalidToken is swallowed, not propagated).
- [x] `sign_in(token: ...)` writes to `session[:bitsmithy_auth_token]` and a subsequent `current_phone` returns the new phone (memo invalidated). *(`phone:` param dropped — the Token's `sub` claim already carries the phone.)*
- [x] `sign_out` removes the session key and a subsequent `current_phone` returns `nil`.
- [x] No `require_authentication!` method is defined on the concern.
- [x] `bundle exec rake` passes.

---

## Slice 7: README, CHANGELOG, and integration walkthrough

**Status:** ✅ Complete
**Type:** HITL — prose needs editorial judgement
**Blocked by:** Slices 1, 2, 3, 4, 5, 6
**User stories covered:** all (the README is how Host-app developers discover what's in the gem)

### What to build

Rewrite the bundler-generated README into v0.1.0 usage documentation. CHANGELOG gets an entry summarising the release. The README must walk a Host-app developer through:

- Installation via `gem 'bitsmithy-auth', github: 'bitsmithy/auth-ruby'` (private gem, not on rubygems.org).
- Configuration block — required fields, sensible default for `session_duration` (24h) and `rate_limit`.
- Generating a Signing key with `SecureRandom.hex(32)`.
- Three end-to-end examples:
  1. **Rails sign-in controller** — `send_code` from a `:new` action, `verify_code` from a `:create` action, `sign_in` on success.
  2. **API bearer token** — pass the Token in an `Authorization: Bearer ...` header, decode with `Bitsmithy::Auth.decode_token`.
  3. **Plain Ruby / Sidekiq** — Verification flow without Rails.
- Test mode usage (`Bitsmithy::Auth.test_mode!` in `test_helper.rb`; the magic `"000000"` code).
- PII redaction guidance — use `Bitsmithy::Auth.redact_phone(result.phone)` in any log statement.
- A "what's deferred to v0.2.0" section listing the engine, install generator, default views, Redis store.
- A pointer to `CONTEXT.md` and `docs/adr/` for vocabulary and decision rationale.

### Acceptance criteria

- [x] README rendered on GitHub displays correctly — code blocks render, no broken links, no leftover bundler placeholders.
- [x] All three usage examples are runnable copy-paste; the reviewer can spot-check each by typing it into `bin/console` (or a Rails app for example 1).
- [x] CHANGELOG entry uses the project's commit-style format and lists the features added in v0.1.0.
- [x] No mention of features that did not actually land in slices 1–6.
- [x] User reviews and approves the prose; revisions land in additional commits if needed.

---

## Coverage cross-check

| PRD module | Built in slice | Tested in slice |
|---|---|---|
| Phone | 1 | 1 (happy), 2 (failure raises raw input per ADR-0004) |
| Token | 1 | 1 (round-trip), 2 (decode failure modes — extracted to test_token_decoding.rb in cleanup) |
| Result, Identity, errors | 1 | 1 (happy), 2 (failure surface) |
| Config | 1 | 1 (defaults), 2 (validate! per field) |
| OTP::TestAdapter | 1 | 1 (happy), 2 (wrong-code failure) |
| OTP::TwilioAdapter | 3 | 3 (success + 7 failure mappings) |
| RateLimiter | 4 | 4 (boundary, isolation, window reset) |
| Stores::MemoryStore | 4 | 4 (counts via increment, window expiry, mutex-protected concurrent burst) |
| Bitsmithy::Auth (façade) | 1 | 1 (happy wiring), 2 (failure conversion), 4 (rate-limit conversion) |
| `redact_phone` helper | 1 | 1 (format); not used in exception messages — see ADR-0004 |
| `test_mode!` env guard | 5 | 5 (all four env cases) |
| Bitsmithy::Auth::Controller | 6 | 6 (session round-trip, memoisation, conditional load) |

---

## Verification Summary

This tasks file was fact-checked against the v0.1.0 implementation on branch `hh/initial-implementation`.

**Claims confirmed:** All seven slices marked complete have matching commits; acceptance criteria align with shipped behaviour; ADR references resolve to existing files; test file paths exist.

**Corrections made:**

- **Slice 2 "What to build"** — said `Phone.normalize raises InvalidPhoneNumber with the input redacted per ADR-0004`. ADR-0004 was revised in slice 2 itself to keep the raw input. Updated to `Phone.normalized raises InvalidPhoneNumber with the raw input retained for debuggability per ADR-0004's revised position` (also corrected the method name to `normalized`).
- **Slice 6 "What to build"** — listed `sign_in(phone:, token:)`. Shipped as `sign_in(token:)`. Updated with rationale note.
- **Coverage cross-check table** — Phone row claimed "redacted message" coverage; corrected to "failure raises raw input per ADR-0004". MemoryStore row claimed "reset" coverage; the `reset!` method was not implemented (YAGNI — see slice 4 discussion). Replaced with the actual covered behaviours.

**Unverifiable claims:** none — every claim either confirmed or corrected against the codebase.
