# bitsmithy-auth

A Ruby gem that verifies a phone number via SMS OTP and returns a signed token. It is a verification primitive, not a user management system — host apps map verified phones to their own user models.

## Language

**Host app**:
The Ruby application that depends on this gem to verify users.
_Avoid_: client, consumer, parent app.

**Identity**:
The verification artifact returned by `decode_token`. Carries a phone, the time it was issued, and the time it expires. It is NOT a user — host apps map an Identity's phone to their own user records.
_Avoid_: User, Account, Session, Principal.

**Phone**:
A phone number normalised to E.164 format. The only identifier this gem knows about.
_Avoid_: number, msisdn, telephone, mobile.

**Verification**:
The act of confirming someone controls a phone — sending an OTP, then checking the entered code. Comprises a send step and a verify step.
_Avoid_: authentication, login, sign-in.

**OTP**:
A short numeric code (six digits) sent to a phone via SMS. Generated, expired, and attempt-limited by Twilio Verify, not by this gem.
_Avoid_: code (when ambiguous), pin, password.

**Token**:
The signed JWT issued on successful verification. Carries the verified phone as the `sub` claim, plus `iat`, `exp`, and `iss: "bitsmithy-auth"`. The host app stores it (typically in `session[]`) and presents it back on subsequent requests, where `decode_token` turns it into an Identity.
_Avoid_: JWT (use only when discussing the wire format specifically), session, cookie, credential.

**Result**:
The value object returned by `send_code` and `verify_code` — carries `success?`, `error` (symbol), `token`, `channel`, and `phone`. Used in place of exceptions for expected failure modes (wrong code, rate-limited, invalid phone).
_Avoid_: response, outcome, status.

**OTP adapter**:
The strategy that sends and verifies codes. `TwilioAdapter` (production) wraps Twilio Verify; `TestAdapter` (test mode) skips the network and accepts the magic code `"000000"`.
_Avoid_: provider, backend, gateway.

**Verify Service**:
A Twilio-side configuration unit referenced by SID. One per host app at minimum; each carries Twilio-side rate limits, SMS templates, and per-channel settings. The gem references one configured via `twilio_verify_service_sid`.
_Avoid_: service (too vague), verification service.

**Test mode**:
A configuration in which the OTP adapter is swapped to `TestAdapter`. Sends always succeed; `"000000"` always verifies. Intended for host-app test suites — never production.
_Avoid_: stub mode, fake mode, mock mode.

**Signing key**:
The HMAC-SHA256 secret used to sign and verify Tokens. Configured via `signing_key`. Must be a high-entropy random string (≥ 32 bytes recommended).
_Avoid_: secret, key, JWT secret.

**Rate limiter**:
The pre-send gate that limits `send_code` attempts per Phone per window. Independent of Twilio Verify's own per-service limits.
_Avoid_: throttle, gate.

**Engine**:
The mountable Rails engine that drives the **Verification flow** end-to-end — it owns the routes and controller, manages the pending-**Phone** session state, and issues the **Token**. It produces an **Identity** and nothing more: it never touches a host app's user records, and it ships no views. Mounted in a single line; all meaning is delegated to the **Host app**.
_Avoid_: app, plugin, mountable app, sign-in engine.

**Verification flow**:
The host-facing sequence the **Engine** drives: enter **Phone** → receive **OTP** → enter code → **Token** issued and stored in `session[]`. Comprises a send step and a verify step, each rendering a host-owned template. On success the **Host app** is redirected to its configured landing path; on an expected failure the same step re-renders with an error.
_Avoid_: login flow, sign-in flow, auth flow, wizard.

## Example dialogue

> **Dev:** When a phone is verified, do we mark the User active?
> **Domain expert:** Wrong direction. This gem doesn't know what a User is. You just got back an Identity carrying the verified Phone. *Your* code decides what that means — for one host app it's `User.find_or_create_by(phone:)`; for another it's looking up an existing admin and rejecting unknown phones.

> **Dev:** Can the Identity carry an email?
> **Domain expert:** No — the gem only does Phone. If you also want email, that's a different verification flow; the Identity stays phone-only.

> **Dev:** I want to test the sign-in form without hitting Twilio in CI.
> **Domain expert:** Use Test mode. `Bitsmithy::Auth.test_mode!` swaps the OTP adapter — `send_code` succeeds and `verify_code` accepts `"000000"`. Don't ship that to production.
