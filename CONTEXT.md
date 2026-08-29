# RubyAuth

RubyAuth is a stateless Ruby authentication library that validates Apple, Google, Email Magic Link, and Passkey credentials.
It returns Authentication Evidence while each Host Application owns identity, persistence, sessions, authorization, and lifecycle.

## Language

**Host Application**:
A Ruby application that uses RubyAuth to validate a Sign-in Method and decides what the successful evidence means.
The Host Application supplies configuration and every durable or temporary state operation.
_Avoid_: Client, consumer, parent app

**Sign-in Method**:
A way to authenticate through Apple, Google, a Verified Email, or a Passkey.
RubyAuth validates a Sign-in Method but never attaches it to an application user.
_Avoid_: User, account, session

**Authentication Evidence**:
The immutable successful Result that identifies the validated Sign-in Method, authentication time, and method-specific verified values.
Authentication Evidence never identifies an application user and never grants application authorization by itself.
_Avoid_: User, application session, application Token

**Result**:
The value returned by a RubyAuth finish or validation operation.
It contains either Authentication Evidence or a stable safe failure symbol and optional safe metadata.
_Avoid_: Provider response, exception payload

**Verified Email**:
An email address whose control a trusted provider or Email Magic Link proved during authentication.
RubyAuth trims surrounding whitespace and case-folds the address without removing dots, plus suffixes, or provider-specific aliases.
_Avoid_: Unverified email, provider profile

**Email Magic Link**:
A ten-minute encrypted credential sent to a Verified Email and validated by RubyAuth after a browser posts it from the URL fragment.
RubyAuth returns a replay identifier, and the Host Application decides atomically whether that identifier can be used once.
_Avoid_: Password reset link, reusable link

**Provider Subject**:
The stable identifier that Apple or Google asserts for one provider identity.
A provider can omit the Verified Email on later authentication while continuing to assert the same Provider Subject.
_Avoid_: Email, application user ID

**Passkey**:
A discoverable WebAuthn credential that requires local user verification without disclosing a biometric to RubyAuth.
The Host Application stores its public credential values and supplies them to RubyAuth for validation.
_Avoid_: Password, biometric identity

**Ceremony Envelope**:
A short-lived authenticated encrypted value that carries OAuth or Passkey challenge state through the browser.
RubyAuth issues and validates the envelope without retaining server-side ceremony state.
_Avoid_: Database session, persistent challenge

**Rails Engine**:
The optional mountable Rails flow that owns authentication routes, validates external input, resets the browser session after successful authentication, and invokes explicit Host Application callbacks.
It never decides which application user the Authentication Evidence represents.
_Avoid_: User management engine, session store

## Example dialogue

**Developer**: Google returned an email and a subject.
Which one is my User?

**Domain expert**: Neither.
RubyAuth returns Authentication Evidence with the Google Provider Subject and Verified Email, and your Host Application resolves them to its own user.

**Developer**: Where does RubyAuth store used Email Magic Links?

**Domain expert**: Nowhere.
RubyAuth validates the encrypted credential and returns its replay identifier, and your Host Application claims that identifier atomically.

**Developer**: Does RubyAuth save a Passkey public key?

**Domain expert**: No.
Your Host Application loads and stores Passkey values, while RubyAuth performs the WebAuthn ceremony and cryptographic validation.
