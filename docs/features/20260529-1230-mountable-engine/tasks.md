# Mountable Engine — Less Host-App Boilerplate — Tasks

Source PRD: [prd.md](./prd.md)

> **Status: ✅ All 7 slices complete.** Verified green — unit suite 46 runs / engine suite 12 runs (request tests against a mounted dummy app) / RuboCop clean. Implemented via vertical-slice TDD; the engine suite runs in a separate process from the framework-agnostic unit suite (see the `test_unit` / `test_engine` split in the Rakefile).

Each slice is a vertical tracer bullet: route → controller → primitive (`send_code`/`verify_code`/`decode_token`) → session → render/redirect → request test, exercised end-to-end under Test mode. Slices are numbered in dependency order. The Engine stays a verification primitive (ADR-0003, ADR-0007) and ships no views (ADR-0008).

Cross-cutting constraints every slice inherits:
- The Engine is defined only when `Rails::Engine` is present; `railties` and the dummy app are development dependencies only — the runtime dependency set never changes.
- Rendered error wording is gem-controlled I18n text surfaced via Rails' default-escaped output; no Host-app input is interpolated unescaped.
- No slice logs an **OTP** or an unredacted **Phone**; the **Signing key** is never hardcoded (Test mode's fixed key stays the Rails-env-guarded exception).

---

## Slice 1: Engine boots, mounts, and renders the Phone form

**Type:** AFK
**Blocked by:** None — can start immediately
**User stories covered:** 1, 8, 9, 15, 16, 17, 18, 20

### What to build

The foundation tracer bullet: a mountable `Bitsmithy::Auth::Engine` (isolated namespace, conditional load mirroring the existing `ActionController` guard) with a `SessionsController` whose first action renders the Host-provided Phone-entry template. Stand up the request-test harness: a minimal dummy Rails app under `test/` that mounts the Engine, supplies stub templates for the two steps, and configures the gem in Test mode. The Engine controller inherits from a configurable parent controller (default the framework base controller) so it picks up the Host's layout and helpers. Establish the named route helpers and the fixed template-name/locals contract that later slices build on, and document the exact list of templates the Host must provide.

### Acceptance criteria

- [ ] `Bitsmithy::Auth::Engine` is defined only when `Rails::Engine` is available; requiring the core gem in a non-Rails context never loads it and never pulls in Rails.
- [ ] A dummy Rails app mounts the Engine at a chosen path; a GET request to the sign-in route renders the Host-provided Phone-entry template with HTTP 200.
- [ ] The Phone-entry template receives its documented locals/route helper (the named route helper for the send step).
- [ ] The Engine controller's parent controller is configurable; the default resolves to the framework base controller, and a configured override is honored.
- [ ] `railties` is a development dependency only; the gemspec's runtime `add_dependency` set is unchanged.
- [ ] Request test (dummy app) covers the mount + render; a unit test covers the conditional-load guard and the `parent_controller` default + override.

---

## Slice 2: Send step — send the OTP, remember the pending Phone, advance

**Type:** AFK
**Blocked by:** Slice 1
**User stories covered:** 3, 5, 6, 7, 16

### What to build

The send step: a POST action that calls `send_code`, and on a success **Result** stores the pending **Phone** in a gem-owned internal session key and redirects to the code-entry step; on an expected failure **Result** (invalid Phone, rate-limited) re-renders the Phone-entry template with a human-readable error. Ship the `en` locale providing a default message for every send-path `Result#error` symbol under `bitsmithy_auth.errors`, and wire the controller to map the failure symbol to its message via I18n and expose it to the re-rendered step.

### Acceptance criteria

- [ ] A valid Phone in Test mode advances to the code-entry step and persists the pending Phone in the gem-owned session key.
- [ ] An unparseable Phone re-renders the Phone-entry template (not a redirect) carrying the `invalid_phone_number` I18n message.
- [ ] A rate-limited send re-renders the Phone-entry template carrying the `rate_limited` I18n message.
- [ ] The shipped `en` locale resolves a non-missing message for each send-path error symbol; a Host-defined locale key overrides the wording.
- [ ] Request tests cover the success advance, the invalid-Phone re-render, and the rate-limited re-render; the error message is asserted via the resolved translation, not a hardcoded English literal.

---

## Slice 3: Verify step — check the code, establish the session, redirect

**Type:** AFK
**Blocked by:** Slice 2
**User stories covered:** 2, 4, 5, 13, 16

### What to build

The money path. A GET action renders the code-entry template (with the pending Phone available as a local); a POST action calls `verify_code` against the stored pending Phone. On success it establishes the session via the Controller concern's `sign_in(token:)`, clears the pending Phone, and redirects to the configured `after_sign_in_path`; on an expected failure it re-renders the code-entry template with the looked-up I18n error and keeps the pending Phone so the user can retry. Add the `after_sign_in_path` config (default the app root).

### Acceptance criteria

- [ ] Verifying with the Test-mode magic code establishes the session such that `current_identity` / `current_phone` resolve downstream to the verified Phone, then redirects to `after_sign_in_path`.
- [ ] `after_sign_in_path` defaults to the app root and honors a configured override.
- [ ] A wrong code re-renders the code-entry template carrying the `invalid_code` I18n message and retains the pending Phone.
- [ ] On success the pending-Phone session key is cleared.
- [ ] Request tests cover the success redirect + downstream `current_identity`, the wrong-code re-render with retained pending Phone, and the `after_sign_in_path` default/override.

---

## Slice 4: Sign-out — clear the session and redirect

**Type:** AFK
**Blocked by:** Slice 1
**User stories covered:** 10, 2

### What to build

A DELETE action that clears the session via the Controller concern's `sign_out` and redirects to the configured `after_sign_out_path`. Add the `after_sign_out_path` config (default the app root).

### Acceptance criteria

- [ ] Signing out clears the session so a subsequent request is unauthenticated (`current_identity` is nil), then redirects to `after_sign_out_path`.
- [ ] `after_sign_out_path` defaults to the app root and honors a configured override.
- [ ] Request test drives sign-in → sign-out → confirms the session is cleared and the redirect target; a unit test covers the default/override.

---

## Slice 5: Optional `on_verified` callback on successful Verification

**Type:** AFK
**Blocked by:** Slice 3
**User stories covered:** 14

### What to build

An optional `on_verified` config callback. When configured, the Engine invokes it exactly once on a successful **Verification** — after the session is established and the pending Phone cleared, before the redirect — passing the verified **Identity** (and the controller context). When unset (the default), nothing extra happens. The callback is never invoked on a failed verification.

### Acceptance criteria

- [ ] `on_verified` defaults to nil; an unset callback leaves the success path unchanged.
- [ ] A configured `on_verified` fires exactly once on success, receiving the verified Identity, and the redirect still occurs.
- [ ] A failed verification never invokes `on_verified`.
- [ ] Request tests assert the single invocation on success and non-invocation on failure.

---

## Slice 6: Opt-in `require_authentication!` guard

**Type:** AFK
**Blocked by:** Slice 1
**User stories covered:** 11, 12

### What to build

Add an opt-in `require_authentication!` to the Controller concern: when the request is not authenticated it redirects to the configured `sign_in_path` (default the Engine's sign-in route); when authenticated it is a no-op so the action proceeds. It is never wired automatically — the Host opts in per controller with a single `before_action`. Add the `sign_in_path` config and reverse the existing test that asserts the concern does not define `require_authentication!`.

### Acceptance criteria

- [ ] An unauthenticated request through `require_authentication!` redirects to the configured `sign_in_path`; `sign_in_path` defaults to the Engine's sign-in route and honors an override.
- [ ] An authenticated request passes through untouched (the guarded action runs).
- [ ] The guard is opt-in: including the concern does not auto-apply it.
- [ ] The prior `test_concern_does_not_define_require_authentication_method` test is replaced by tests asserting the new redirect/pass-through/opt-in behavior.

---

## Slice 7: Error-locale completeness and documentation reconciliation

**Type:** AFK
**Blocked by:** Slices 2, 3, 4, 5, 6
**User stories covered:** 6, 7, 9, 19, 20

### What to build

Close the loop. Add a locale smoke test asserting that every `Result#error` symbol the Engine can surface resolves to a non-missing `bitsmithy_auth.errors.<symbol>` translation in the shipped `en` locale (guards against a new error symbol with no default). Reconcile the documentation: update the README to describe the mounted Engine, the one-line install + config, the exact required-template list with their locals/route helpers, the opt-in `require_authentication!`, and the downstream Identity-mapping pattern; move the Engine and views out of the "deferred to v0.2.0" table into shipped status; make the gemspec description accurate; and add a CHANGELOG entry.

### Acceptance criteria

- [ ] A locale smoke test fails if any Engine-surfaced error symbol lacks an `en` default message.
- [ ] README documents the mount + config, the required templates and their locals/route helpers, `require_authentication!`, and the downstream `current_identity` mapping; the v0.1.0/v0.2.0 status table no longer lists the Engine/views as deferred.
- [ ] The gemspec description matches what ships; CHANGELOG has an entry for the Engine and `require_authentication!`.
- [ ] No documented example hardcodes a Signing key; all reference ENV/secrets, consistent with the existing initializer example.
