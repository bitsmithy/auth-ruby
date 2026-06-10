# Install Generator — Tasks

Source PRD: [prd.md](./prd.md)

## Slice 1: Generator skeleton

**Type:** AFK
**Blocked by:** None
**User stories covered:** 1

### What to build

A `Bitsmithy::Auth::Generators::InstallGenerator` class (inside
`lib/generators/`) that subclasses `Rails::Generators::Base`, guarded by
`defined?(Rails::Generators)` so non-Rails consumers never load it.
Running `rails generate bitsmithy:auth:install` produces no error but does
nothing yet — no files created, no routes modified.

The generator declares the templates directory and the source paths so
downstream slices can hook into the standard `template` / `copy_file`
methods.

### Acceptance criteria

- [x] Generator class exists at the expected namespace and subclasses
      `Rails::Generators::Base`
- [x] `defined?(Rails::Generators)` guard prevents load outside Rails
- [x] `rails generate bitsmithy:auth:install` runs without error
- [x] Generator test loads and asserts the class is defined

**Status:** ✅ Complete

---

## Slice 2: Scaffolds initializer

**Type:** AFK
**Blocked by:** Slice 1
**User stories covered:** 1, 2, 3

### What to build

The generator creates `config/initializers/bitsmithy_auth.rb` with:

- Production branch: fetches `BITSMITHY_AUTH_SIGNING_KEY`,
  `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_VERIFY_SERVICE_SID`
  from ENV, requires `twilio_ruby`, instantiates `TwilioAdapter`.
- Dev/test branch: enables `Bitsmithy::Auth.test_mode!` (signing key
  defaults to the non-production dummy via `test_mode!`).
- Commented-out optional overrides (`after_sign_in_path`,
  `after_sign_out_path`, `on_verified`).

The template is shipped as `initializer.rb.erb` in the generator's
templates directory.

### Acceptance criteria

- [x] Running the generator creates
      `config/initializers/bitsmithy_auth.rb`
- [x] File contains the production/ENV branch markers
- [x] File contains the `unless Rails.env.production?` / `test_mode!` guard
- [x] File contains commented-out optional overrides
- [x] Test asserts these content markers

**Status:** ✅ Complete

---

## Slice 3: Scaffolds view templates

**Type:** AFK
**Blocked by:** Slice 1
**User stories covered:** 1, 4

### What to build

The generator creates two view templates:

- `app/views/bitsmithy/auth/sessions/new.html.erb` — phone-entry form with
  `inputmode="tel"`, posts to `send_code_path`, displays `@error`.
- `app/views/bitsmithy/auth/sessions/edit.html.erb` — code-entry form for
  six-digit code, posts to `verify_path`, displays `@phone` and `@error`.

Both templates ship as ERB source files in the generator's templates
directory. They are basic stubs — the host app is expected to edit them.

### Acceptance criteria

- [x] Running the generator creates `new.html.erb` at the expected path
- [x] Running the generator creates `edit.html.erb` at the expected path
- [x] Phone form template references `send_code_path` and `@error`
- [x] Code form template references `verify_path`, `@phone`, and `@error`

**Status:** ✅ Complete

---

## Slice 4: Inserts mount line

**Type:** AFK
**Blocked by:** Slice 1
**User stories covered:** 1, 5, 6

### What to build

The generator reads `config/routes.rb`, checks for an existing
`mount Bitsmithy::Auth::Engine` line, and inserts it after the
`Rails.application.routes.draw` block opening if absent.

If the mount line already exists, the generator skips the insertion
silently — the file is not modified.

### Acceptance criteria

- [x] Running the generator adds `mount Bitsmithy::Auth::Engine => "/auth"`
      to `config/routes.rb`
- [x] Running the generator a second time does not duplicate the mount line
- [x] Running the generator when the mount line already exists leaves the
      file unchanged

**Status:** ✅ Complete

---

## Slice 5: Force overwrite flag

**Type:** AFK
**Blocked by:** Slices 2, 3, 4
**User stories covered:** 7, 8

### What to build

Standard Rails generator behaviour: existing files (initializer, view
templates) are skipped on re-run unless `--force` is passed. When
`--force` is passed, all existing files are overwritten with the template
defaults. The mount line insertion remains idempotent regardless of the
flag.

This slice is mostly wiring — Rails generators handle skip vs. overwrite
natively when using `copy_file` / `template`. The work is ensuring all
file-creation calls use the standard methods that respect `--force`.

### Acceptance criteria

- [x] Re-running the generator without `--force` does not overwrite
      existing initializer or templates
- [x] Re-running the generator with `--force` overwrites existing
      initializer and templates
- [x] Mount line is never duplicated regardless of `--force` flag

**Status:** ✅ Complete
