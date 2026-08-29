---
status: superseded by ADR-0009
---

# Twilio Verify is the OTP backend

The gem delegates OTP generation, delivery, expiry, attempt limiting, and SMS-pumping fraud detection to Twilio Verify (Twilio's managed verification SaaS). The gem itself never generates, stores, expires, or counts attempts against an OTP — those concerns live on Twilio's side, keyed by a per-host-app Verify Service SID.

The motivating constraint is that bespoke OTP machinery is a meaningful surface area to maintain (`verifications` table, code generation entropy, expiry sweeper, attempt counter, fraud heuristics for SMS pumping). Twilio Verify removes all of that for a flat ~$0.05 per verification. We considered raw Twilio SMS (cheaper per message but the operator now owns expiry, attempt limits, and fraud detection), Vonage Verify, and MessageBird Verify — all functionally equivalent at the API surface but more expensive in Ruby SDK maturity and Verify-feature parity. The cost premium of Verify over raw SMS is genuinely worth not maintaining the OTP plumbing.

Lock-in cost: switching providers later means coordinating a flip across all host apps that have provisioned Twilio Verify Services. The interface (`OTP::Adapter#send_code`, `#verify_code`) is provider-agnostic, so a `VonageAdapter` could ship without breaking the public API — but the operational coordination is real and should be costed honestly if the question is ever revisited.
