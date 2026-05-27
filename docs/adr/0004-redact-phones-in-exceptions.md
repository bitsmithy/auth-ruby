# Phone numbers are redacted in exception messages

`InvalidPhoneNumber` and other exceptions raised by the gem present Phones in a masked form (`+1******1234`) rather than the full E.164 string. The gem ships `Bitsmithy::Auth.redact_phone(phone)` as a public helper so host apps can apply the same redaction in their own log statements.

The motivating leak path is exception messages propagating through error trackers (Sentry, Honeybadger) and host-app logs, where Phones get archived, indexed, and shared across teams long after the request that produced them. Redacting at the source removes that exposure without forcing every host app to reinvent log scrubbing.

`Result#phone` carries the full Phone unredacted — the success path needs it to render "code sent to +1******1234" or to write to the host app's User record. Host apps that log `Result` objects raw will leak the Phone; the README will steer them toward `redact_phone(result.phone)` instead.

Out of scope for v0.1.0: a Lograge-compatible automatic filter. The helper is enough — host apps wire it into their preferred logging stack themselves.
