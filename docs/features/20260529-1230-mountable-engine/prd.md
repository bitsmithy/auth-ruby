# Mountable Engine — Less Host-App Boilerplate — PRD

## Problem Statement

To use `bitsmithy-auth` today, a Host app must hand-write roughly forty lines of mechanical plumbing that is identical across every app: a four-action sign-in controller (send a code, store the pending Phone, verify the code, sign out), an error-symbol-to-message mapping, the routes wiring those actions, and a `require_authentication!` guard. None of this is a decision the Host app benefits from owning — it is the same boilerplate reproduced verbatim from the README in project after project. The gem already exposes the right primitive (`send_code` / `verify_code` / `decode_token`), but the distance from "gem installed" to "a user can sign in" is far too long.

## Solution

Ship a mountable **Engine** that owns the entire **Verification flow** — routes and controller — so a Host app gets a working sign-in flow from one `mount` line plus configuration. The Engine drives the two-step flow (enter **Phone** → receive **OTP** → enter code → **Token** issued and stored in `session[]`), establishes the session on success, and redirects to a configured landing path. The Host app supplies only the two things that are genuinely app-specific: the **view templates** (so every app owns its own UI) and the meaning of a verified **Identity** (mapping the verified **Phone** to its own user records, read downstream via `current_identity`). Everything mechanical — pending-Phone session state, error wording, the redirect plumbing, the per-request guard — moves into the gem.

The Engine remains a verification primitive, not a user system: it never defines or persists a user, never owns a phone-change or revocation flow, and never decides what a verified Phone means. Its only output is an Identity. See ADR-0007 for the boundary and ADR-0008 for why it ships no views.

## User Stories

1. As a **Host app** developer, I want to mount the **Engine** with one line in my routes, so that I get the full **Verification flow** without writing a controller.
2. As a Host app developer, I want to configure the Engine in the same initializer I already use for `signing_key` and Twilio settings, so that there is a single place to set everything up.
3. As a Host app developer, I want the send step (`create`) to call `send_code`, remember the pending **Phone**, and advance to the verify step, so that I do not re-implement that orchestration.
4. As a Host app developer, I want the verify step to call `verify_code`, and on success establish the session and redirect to my configured landing path, so that a successful **Verification** lands the user where my app wants them.
5. As a Host app developer, I want an expected failure (wrong **OTP**, rate-limited, invalid Phone) to re-render the current step with a human-readable error, so that users get feedback without me writing error-handling code.
6. As a Host app developer, I want the error wording to ship with sensible English defaults for every error symbol, so that the flow reads correctly out of the box.
7. As a Host app developer serving non-English users, I want to override any error wording by defining the same I18n keys in my own locale files, so that I can localize without owning the gem's strings or templates.
8. As a Host app developer, I want to provide my own view templates for the Phone form and the code form, so that the sign-in screens match my app's branding and layout exactly.
9. As a Host app developer, I want the templates I write to receive a documented set of locals and route helpers, so that I know what is available when building the forms without reading the gem's source.
10. As a Host app developer, I want a sign-out route that clears the session and redirects to a configured path, so that logging out is also handled for me.
11. As a Host app developer, I want an opt-in `require_authentication!` helper that redirects unauthenticated requests to the Engine's sign-in route, so that protecting a controller is a single `before_action`.
12. As a Host app developer, I want `require_authentication!` to remain opt-in per controller (never auto-applied), so that I keep explicit control over which actions are public.
13. As a Host app developer, I want to read the verified **Identity** downstream via `current_identity` / `current_phone`, so that I decide what a verified Phone means (`User.find_or_create_by(phone:)` or a strict allow-list) wherever I need it.
14. As a Host app developer with eager provisioning needs, I want an optional `on_verified` callback invoked at the moment of successful **Verification**, so that I can react immediately if I choose to, without it being mandatory.
15. As a Host app developer, I want the Engine's controller to inherit from a configurable parent controller, so that it picks up my application layout, helpers, and before-actions.
16. As a Host app developer running my test suite, I want the Engine flow to work under **Test mode**, so that I can exercise sign-in end-to-end with the magic code `"000000"` and no Twilio calls.
17. As a developer of a non-Rails Ruby app, I want `require "bitsmithy/auth"` to never pull in Rails, so that the framework-agnostic core API stays usable without the Engine.
18. As a maintainer, I want the Engine to load only when Rails is present, so that the conditional-load contract matches the existing `ActionController` guard for the Controller concern.
19. As a maintainer, I want the gemspec, README, and CHANGELOG to stop describing the Engine and views as deferred-to-v0.2.0 and instead document them as shipped, so that the docs match reality.
20. As a Host app developer, I want a clear, documented list of exactly which templates I must create and where, so that "one `mount` line" has a precise, short follow-up rather than a guessing game.

## Implementation Decisions

### Modules

- **`Engine`** — a thin `Rails::Engine` subclass with an isolated namespace. Defined only when `Rails::Engine` is available (mirroring the existing `ActionController` guard for the Controller concern); a non-Rails consumer never loads it. Wires the Engine's routes and registers the shipped `en` locale. Carries no flow logic itself.
- **`SessionsController`** — the deep module that drives the Verification flow. Actions: render the Phone form; send step (`send_code`, persist the pending Phone in session, advance to the verify step); render the code form; verify step (`verify_code`, on success `sign_in` + redirect to the configured landing path, on expected failure re-render the current step with the looked-up error message); sign-out (clear session + redirect). It renders host-owned templates only and inherits from a configurable parent controller so it inherits the Host app's layout, helpers, and before-actions.
- **Engine routes** — named routes for: the Phone form (GET), the send step (POST), the code form (GET), the verify step (POST), and sign-out (DELETE). These named route helpers are part of the Engine's public contract and are available to host templates.
- **`Config` additions** — `after_sign_in_path` (default the app root), `after_sign_out_path` (default the app root), `sign_in_path` (the redirect target for `require_authentication!`, default the Engine's sign-in route), an optional `on_verified` callback, and a configurable parent controller (default the framework base controller). The pending-Phone session key is gem-owned and internal.
- **`Controller` concern additions** — an opt-in `require_authentication!` that redirects to the configured sign-in path when the request is not authenticated. It is never wired automatically.
- **Error I18n** — a shipped `en` locale providing a default message for every `Result#error` symbol under a `bitsmithy_auth.errors` namespace, plus controller logic that maps a failure Result's symbol to its message via I18n and exposes it to the re-rendered step. Host apps override wording by defining the same keys.

### Interfaces and contracts

- **Mount contract.** The Host app mounts the Engine at a path of its choosing in its router. The Engine exposes named route helpers (under the isolated namespace) for each step; host templates use these helpers for their form actions. Host paths are reached via the standard main-app route proxy.
- **Template contract (host-owned).** The Host app provides exactly two templates — one for the Phone-entry step and one for the code-entry step — at the conventional Rails view path for the Engine's controller. Each template receives a documented set of locals/route helpers: the current pending Phone where applicable, the error message string when re-rendered after a failure, and the named route helpers for its form action. The exact template names and locals are fixed and documented; no third template is required. See ADR-0008.
- **Verification flow state machine.** The two-step flow is: Phone form → (send step: `send_code`) → on success store pending Phone and render code form; on failure re-render Phone form with error. Code form → (verify step: `verify_code` against the stored pending Phone) → on success `sign_in(token:)`, clear the pending Phone, invoke `on_verified` if configured, redirect to `after_sign_in_path`; on failure re-render code form with error and keep the pending Phone. Sign-out → `sign_out`, redirect to `after_sign_out_path`.
- **Identity seam.** No mandatory mid-flow callback. The Engine establishes the session and redirects; the Host app maps Identity → its own user records downstream by reading `current_identity` / `current_phone`. The optional `on_verified` callback exists only for hosts that want to react at verify time (see ADR-0007).
- **Error presentation.** Failure Result symbols (`:invalid_code`, `:rate_limited`, `:invalid_phone_number`, and the Twilio-origin symbols) map to messages via `I18n.t("bitsmithy_auth.errors.<symbol>")`, with a shipped `en` default for each. The looked-up message is exposed to the re-rendered step as the `@error` instance variable. See ADR-0008.

### Architectural decisions

- The Engine is the implementation of the "verification primitive, not user system" stance under load: it ships the flow but never the user lifecycle. See **ADR-0007** (amends ADR-0003's no-sign-in-controller line) and **ADR-0008** (no shipped views; I18n error wording).
- **Conditional load**, not a hard Rails runtime dependency. `railties` (and a dummy app) are development dependencies only. The runtime dependency set is unchanged.
- **Reversal recorded:** the Controller concern gains `require_authentication!`, reversing the README's prior "deliberately no `require_authentication!`" note now that the Engine provides a canonical redirect target (ADR-0007).
- **Docs reconciliation:** the gemspec already promises a mountable engine while the README defers it to v0.2.0. This feature makes the gemspec true and updates README + CHANGELOG to describe the Engine, the template contract, and `require_authentication!` as shipped.

## Testing Decisions

A good test in this codebase asserts external behavior, not plumbing: existing tests assert that `send_code` returns a success Result in Test mode, that a verified code yields a decodable Token carrying the Phone, that a rate-limited send carries the normalised Phone, and that the config guard raises on a missing field. Tests use Minitest with `mocha/minitest`; `ConfigHelper#setup` resets config and stubs `Rails.env`; `configure_for_tests` enables Test mode with a fixed signing key. The Controller concern is currently tested via a `FakeController` that mixes in the concern over a plain session Hash.

Per the decision to test all new code:

- **`SessionsController` (integration/request tests).** Boot a minimal dummy Rails app with the Engine mounted, stub templates for the two steps, and configured paths. Exercise the whole flow under Test mode: the send step advances to the code form and stores the pending Phone; the verify step with `"000000"` establishes the session and redirects to `after_sign_in_path`; a wrong code re-renders the code form with the I18n error and keeps the pending Phone; an unparseable Phone re-renders the Phone form with the invalid-Phone error; sign-out clears the session and redirects to `after_sign_out_path`; `on_verified` fires exactly once on success and not on failure. These request tests transitively cover the thin Engine shell and the routes.
- **`Config` additions (behavioral coverage).** Rather than asserting literal default values, the request tests exercise the config through behavior: the redirect targets prove `after_sign_in_path` / `after_sign_out_path` / `sign_in_path` are actually consulted (each tested at its default and with an override); `parent_controller` is proven by the host base controller's `before_action` running on engine responses; `on_verified` defaulting to nil is implied by the flows that never configure it.
- **`require_authentication!` (request tests + concern presence).** Behavior is covered by request tests against a host controller guarded by the concern: an unauthenticated request redirects to the configured sign-in path (default and override), an authenticated request passes through, and the engine's own controller skips the guard so the flow stays reachable. A concern unit test asserts the guard is now defined, replacing the prior `test_concern_does_not_define_require_authentication_method`.
- **Error I18n (locale smoke test).** Every `Result#error` symbol the controller can surface resolves to a non-missing `bitsmithy_auth.errors.<symbol>` translation in the shipped `en` locale (guards against an error symbol with no default message).

Prior art: `test/bitsmithy/auth/test_controller.rb` (concern over a fake controller), `test/bitsmithy/test_auth.rb` (Result/flow behavior in Test mode), `test/support/config_helper.rb` and `rails_env_stub.rb` (config reset + Rails env stub). The request tests introduce new infrastructure — a dummy Rails app under `test/` — which is the standard way to test a mountable engine.

## Out of Scope

- Shipping any view templates, stylesheets, or an eject generator (ADR-0008): the Host app owns 100% of rendering.
- An install generator that scaffolds an initializer/controller/views into the Host app: the Engine supersedes the need for a scaffolded controller, and views are intentionally host-owned.
- Any user-lifecycle feature: User model, sessions table, phone-change flow, hard revocation, account merge/deletion (ADR-0003 and ADR-0007 keep these as Host-app concerns).
- New channels (voice / WhatsApp), email OTP / TOTP, and a Redis-backed rate-limit store (still deferred per the README roadmap).
- Auto-applying `require_authentication!` (security default stays open; opt-in per controller).
- Changing the wire contract: Phone (E.164), Token (HS256 JWT with `iss: "bitsmithy-auth"`), error symbols, and Identity shape are unchanged, preserving cross-language compatibility (ADR-0006).

## Further Notes

- "One `mount` line just works" is precise but qualified: routing and flow work immediately; rendering requires the two host templates to exist (ADR-0008). User story 20 makes the required-templates list an explicit deliverable so the follow-up is short and unambiguous.
- The pending-Phone session key is gem-owned and internal; it sits alongside the existing `bitsmithy_auth_token` session key used by the Controller concern.
- Test mode already swaps the OTP adapter and works through the same `send_code` / `verify_code` entry points the Engine calls, so the Engine inherits Test mode for free — the request tests rely on this.
