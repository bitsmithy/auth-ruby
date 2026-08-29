# Keep RubyAuth stateless behind Authentication Evidence

A Host Application can authenticate one user through Apple, Google, a Verified Email, or several Passkeys, but RubyAuth cannot know how those methods map to that application's user model.

RubyAuth will validate authentication protocols and return failure or successful Authentication Evidence without owning a database, persistent cache, user, application session, or application Token.
Its optional Rails Engine may send email, reset the browser session, call explicit host state ports, and cache only disposable public provider signing keys.

The Host Application owns identity resolution, replay protection, rate limiting, Passkey storage, application sessions, authorization, and lifecycle.
This supersedes the phone-only verification, Twilio, stateless application Token, and phone-oriented Engine decisions in ADRs 0001, 0003, 0005, and 0007.
