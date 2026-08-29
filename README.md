# RubyAuth

Stateless passwordless authentication for Ruby applications.

RubyAuth validates Apple, Google, Email Magic Link, and Passkey credentials.
It returns **Authentication Evidence** and never owns an application user, database, persistent cache, application session, or application Token.
The Host Application resolves the evidence to its user and owns every lifecycle decision.

## Public contract

Every finish operation returns a `Bitsmithy::Auth::Result`.
A successful Result contains `evidence` and a failed Result contains a stable `error` symbol.

Authentication Evidence contains:

- `sign_in_method`
- `authenticated_at`
- `email` when verified and supplied
- `provider` and `subject` for Apple or Google
- `credential_id`, `user_handle`, and `signature_count` for a Passkey
- `replay_id` for an Email Magic Link

RubyAuth does not convert these values into an application user.

## Host-owned state

The Host Application owns:

- Identity resolution and account linking.
- Email request rate limits.
- Atomic Email Magic Link replay claims.
- Passkey credential storage and counter updates.
- Browser and API sessions.
- Authorization and post-authentication routing.
- Provider credentials, encryption keys, sender details, and relying-party configuration.

## Email Magic Links

`request_email_magic_link` normalizes the email, creates a ten-minute authenticated encrypted credential, and invokes the configured Action Mailer delivery.
The generated link carries the credential in its URL fragment so the initial GET cannot authenticate or consume it.
The generated exchange template posts the fragment credential with the Rails CSRF token.

`verify_email_magic_link` returns Verified Email Authentication Evidence and a replay identifier.
The Host Application must claim that identifier atomically before creating its session.

## Apple and Google

`start_apple_authentication` and `start_google_authentication` produce authorization URLs with encrypted state, nonce, PKCE, a safe return path, and a ten-minute expiry.
The matching finish operations validate signature, issuer, audience, state, nonce, PKCE exchange inputs, provider time claims, stable subject, and verified email when supplied.

Apple private relay addresses are returned as ordinary normalized Verified Emails.
Apple can omit email after first authorization, so Host Applications must persist the first successful provider mapping.

Provider HTTP clients use bounded connection and response timeouts.
Public provider signing keys can be cached briefly in memory and are never authoritative user state.

## Passkeys

`start_passkey_registration` produces discoverable WebAuthn registration options and an encrypted Ceremony Envelope.
`finish_passkey_registration` validates origin, relying party, challenge, user handle, local user verification, and the no-identifying-attestation policy before returning persistence-ready public values.

`start_passkey_authentication` produces discoverable authentication options for conditional browser mediation.
`finish_passkey_authentication` accepts the Host Application's stored public credential values and returns Passkey Authentication Evidence plus a validated signature-counter update.

RubyAuth never stores Passkey data or receives a biometric.

## Rails Engine

Mount `Bitsmithy::Auth::Engine` to use the optional Rails routes for:

- Entry choice.
- Apple and Google start and callbacks.
- Email Magic Link request, sent, exchange, and verification.
- Passkey registration and authentication ceremonies.

The Engine renders Host Application templates or generated starter templates.
After successful authentication it resets the browser session, invokes `on_authenticated` with Authentication Evidence and the new session container, and returns to the validated application-relative destination.

The Host Application supplies callbacks for rate limiting, replay claims, identity completion, Passkey authorization, credential lookup, credential storage, and counter updates.

## Configuration

Configure only the methods that the Host Application enables.
Call `validate!` after assigning the required host callbacks and enabled provider settings.
Configuration accepts values directly and does not prescribe environment variable names.
The install generator provides an environment-variable-based starting template that applications can replace.

## Testing

Provider clients and the WebAuthn relying party are injectable through configuration.
This keeps tests deterministic without live Apple, Google, email, or authenticator calls.

`Bitsmithy::Auth::Testing.authentication_evidence` can create deterministic evidence only when passed the `test` or `development` environment.
It refuses production use.

## Security properties

- Authentication inputs are validated at protocol boundaries.
- OAuth state and Passkey challenges use purpose-bound encrypted envelopes.
- Return destinations must be application-relative.
- Email Magic Link redirects must use absolute HTTPS URLs.
- Expected failures return stable symbols instead of raw provider exceptions.
- Credentials, authorization codes, link fragments, Passkey responses, and full personal data must not be logged.

See `CONTEXT.md` for canonical language and `docs/adr/0009-stateless-authentication-evidence.md` for the architectural boundary.
