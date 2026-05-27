# Gem is a verification primitive; lifecycle is host-app concern

This gem provides exactly one thing: proof that someone controls a Phone at a point in time, expressed as a signed Token decoded into an Identity. Everything user-shaped — the User record itself, sign-up vs sign-in distinctions, phone-number change flows, hard revocation ("kick this user out now"), session management beyond Token expiry, account merge, account deletion — is left to the host app.

The motivation is that "what a verified phone means" varies per host app: in one project it's a Customer, in another it's an Admin allowed past a gate, in another it's an Auto-created guest with reduced privileges. Bundling user management into the gem would force one shape onto all host apps and pull state into the gem (a `users` table) that breaks the multi-project reuse goal.

Consequences host apps inherit: they call `User.find_or_create_by(phone:)` themselves; they implement their own "change phone" flow by running the gem's verification on the new number then updating their own records; they implement hard revocation by storing a per-Phone `not_before` cutoff and rejecting Identities whose `issued_at` precedes it.

This is the explicit no-s ADR: future contributors should not add a `Bitsmithy::Auth::User`, a sessions table, a phone-change controller, or a revocation list to the gem. Those are exits from this design, not extensions of it.
