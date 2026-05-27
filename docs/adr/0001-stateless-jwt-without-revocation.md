# Stateless JWT tokens with no revocation list

For v0.1.0, Tokens are signed JWTs (HS256) carrying an `exp` claim and no server-side state. `sign_out` clears the session cookie but does not invalidate the Token — a leaked Token remains valid until `exp`. The default `session_duration` is 24 hours, chosen so the blast radius of a leaked Token stays small without forcing users through SMS verification every page load.

We considered maintaining a revocation list keyed by a `jti` claim, and using opaque session IDs with server-side storage. Both negate the architectural payoff of JWTs (statelessness, no runtime store dependency on every authenticated request) and would force every host app to provision a revocation store. For personal-project auth where stolen-Token risk is genuinely low, the short-expiry approach is the right defense.

Host apps that later need hard revocation can layer it on themselves: store a per-Phone `not_before` cutoff and reject any Identity whose `issued_at` precedes it. The gem stays stateless; revocation becomes a host-app concern when wanted.
