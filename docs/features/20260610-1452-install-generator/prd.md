# Install Generator — PRD

## Problem Statement

After mounting the Engine, a Host app must create three things from scratch: an initializer with the four required config fields and conditional `test_mode!`, two view templates (Phone form, code form) with the correct locals and route helpers, and one `mount` line in routes. Each of these is documented but not automated — the developer reads the README, copies patterns, and hand-writes boilerplate that is nearly identical across every Host app. The gap from "gem installed" to "sign-in works" is several manual steps that a generator can close.

## Solution

A single `rails generate bitsmithy:auth:install` command that scaffolds everything a Host app needs to render the Engine's sign-in flow. Developers own every generated file and are free to edit them; the generator is a starter, not a jail.

## User Stories

1. As a Host app developer, I want to run one generator command, so that I get a working initializer, view templates, and the mount line without reading the README.
2. As a Host app developer, I want the generated initializer to configure Twilio credentials from ENV vars in production, so that my production setup is secure and follows Rails conventions.
3. As a Host app developer, I want the generated initializer to enable test mode in development and test environments automatically, so that I can develop and test without Twilio credentials.
4. As a Host app developer, I want the generated Phone-form template and code-form template to render with the correct form action and locals out of the box, so that the sign-in flow works immediately after generation.
5. As a Host app developer, I want the mount line inserted into `config/routes.rb` (not duplicated if already present), so that routing works without manual editing.
6. As a Host app developer, I want the generator to be idempotent — re-running it does not duplicate the mount line or overwrite my edited templates — so that it is safe to run again after upgrading the gem.
7. As a Host app developer, I want a `--force` flag to overwrite existing files when I intend to reset them, so that I can regenerate the defaults on demand.
8. As a Host app developer upgrading the gem, I want to re-run the generator to get an updated initializer without losing my view templates, so that upgrades are low-risk.

## Implementation Decisions

- **Generator class.** A `Rails::Generators::Base` subclass at `Bitsmithy::Auth::Generators::InstallGenerator`. Namespaced under the gem's module, registered when `Rails::Generators` is defined, so non-Rails consumers never load it.
- **Template files.** Three ERB source templates shipped alongside the generator in `lib/generators/bitsmithy/auth/templates/`:
  - `initializer.rb.erb` — the config initializer, including the `Rails.env.production?` branch for Twilio vs. test mode, commented-out optional overrides, and the signing key fetched from ENV.
  - `new.html.erb` — Phone-entry form: text input with `inputmode="tel"`, form posts to `send_code_path`, error display via `@error`.
  - `edit.html.erb` — Code-entry form: text input for the six-digit code, form posts to `verify_path`, hidden field or display for `@phone`, error display via `@error`.
- **Route insertion.** `config/routes.rb` is read, checked for the `mount Bitsmithy::Auth::Engine` line, and the line is inserted after the first `Rails.application.routes.draw` block opening if absent. If present, skipped silently (idempotent).
- **Conditional load.** The generator file is loaded only when `Rails::Generators` is defined (or `defined?(Rails::Generators)`), mirroring the existing `Rails::Engine` and `ActionController` guards.
- **Overwrite behaviour.** Rails generator defaults: existing files are skipped unless `--force` is passed. The mount insertion is never duplicated.
- **No User model, no migration.** Consistent with ADR-0003 and ADR-0007 — the gem is a verification primitive.

## Testing Decisions

A good test in this codebase asserts external behaviour, not plumbing. For a Rails generator, the external behaviour is the set of files created, the content of those files, and the idempotence of re-running.

- **Generator integration tests.** Use `Rails::Generators::TestCase` with a minimal Rails application scaffold (no DB, no routes beyond the default). Tests exercise:
  - `test_generator_creates_initializer` — asserts the initializer file exists and contains production/ENV and dev/test guard markers.
  - `test_generator_creates_view_templates` — asserts both template files exist at the expected paths.
  - `test_generator_inserts_mount_line` — asserts the mount line is present in `routes.rb`.
  - `test_generator_is_idempotent` — running twice does not duplicate the mount line or overwrite existing files.
  - `test_generator_force_overwrites` — `--force` overwrites existing files.
- **Prior art.** No existing generator in this codebase; the tests follow the standard Rails generator testing pattern used across the ecosystem (`Rails::Generators::TestCase`, fixture destination root, `run_generator`).

## Out of Scope

- Shipping any view templates as part of the gem load (ADR-0008 — the engine ships no views; the generator scaffolds them into the host app, which is distinct).
- An eject generator to customise the SessionsController — the Engine already owns the controller, and the host customises via config.
- A rake task or non-Rails equivalent — the generator is a Rails-only convenience.
- Scaffolding a User model, migration, or any user-lifecycle feature (ADR-0003, ADR-0007).
- Adding the `cgi` gem or any new runtime dependency.

## Further Notes

- ADR-0008 says the engine ships no views. The generator scaffolding views into the host app does not violate this — it creates host-owned files that the user is free to edit, eject, or delete. The engine itself still has zero views.
- The `unless Rails.env.production?` guard for `test_mode!` relies on ADR-0002's Rails-env check. In development, `"000000"` will verify successfully; in test, the same. The signing key defaults to a non-production dummy via `test_mode!`.
- The four Twilio ENV vars (`BITSMITHY_AUTH_SIGNING_KEY`, `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_VERIFY_SERVICE_SID`) match the existing documented configuration contract.
