---
status: superseded by ADR-0009
---

# Phone redaction is context-dependent

Phone numbers in exception messages are redacted **when they represent a successfully-parsed Phone** (e.g. rate-limit failures, Twilio operation failures, any future exception that surfaces a Phone the gem already accepted as valid). The gem ships `Bitsmithy::Auth.redact_phone(phone)` as a public helper for Host apps to apply the same masking in their own log statements.

**Inputs that failed parsing are kept raw** in `InvalidPhoneNumber#message`. The motivating leak path is exception messages propagating through error trackers (Sentry, Honeybadger) and host-app logs — but a string that failed `Phonelib.parse` is, by definition, not a phone Phonelib recognises. It may be a typo of a real number (some PII residue), or it may be unrelated garbage. Redacting it destroys the debuggability of "why did my input fail?" while providing only marginal PII protection. For a small gem whose Host-app developers are also its operators, the debuggability win outweighs the marginal redaction value.

`Result#phone` carries the un-redacted normalized Phone — the success path needs it to render "code sent to +1******1234" or to write to the host app's User record. Host apps that log `Result` objects raw will leak the Phone; the README will steer them toward `redact_phone(result.phone)` in any log statement.

The redaction format itself: keep the leading two chars (e.g., `+1`), mask the middle with `*` preserving length, keep the trailing four digits. Example: `"+15555551234"` → `"+1******1234"`.

Out of scope for v0.1.0: a Lograge-compatible automatic filter. The helper is enough — host apps wire it into their preferred logging stack themselves.
