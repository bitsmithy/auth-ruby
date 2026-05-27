# Test mode is guarded by Rails environment

`Bitsmithy::Auth.test_mode!` raises `ConfigurationError` unless `Rails.env.test?` or `Rails.env.development?` is true at call time. No environment-variable escape hatch is provided. In non-Rails contexts (no `Rails` constant defined) the method also refuses — those consumers can stub the OTP adapter directly instead.

The blast radius of accidentally enabling Test mode in production is total: every Phone can sign in by entering `000000`. We chose a hard guard over a softer warning because the failure mode is not "noisy" — host-app log review would not necessarily catch it before the first compromised account.

The cost is that one host-app pattern (calling `test_mode!` from a non-Rails Rake script for ad-hoc verification) becomes impossible. That cost is small; the protection is large.
