# Pattern A — language in the repo name, not in the package name

This gem is named `bitsmithy-auth` (RubyGem) → `Bitsmithy::Auth` (module). The repo is `bitsmithy/auth-ruby`. Sibling implementations follow the same shape: `bitsmithy/auth-python` will publish a `bitsmithy-auth` PyPI package, `bitsmithy/auth-go` will be imported as `github.com/bitsmithy/auth-go`.

The motivating constraint is Ruby's `foo-bar` → `Foo::Bar` namespace convention. Naming the gem `bitsmithy-auth-ruby` would force the module to `Bitsmithy::Auth::Ruby` (awkward) or require a non-default `require_paths` override (fights the convention forever). Putting the language in the *repo* name preserves the natural namespace and keeps package names registry-clean across all three languages. The language is still always visible at the install site: `gem 'bitsmithy-auth', github: 'bitsmithy/auth-ruby'`.

We considered Pattern B (language in everything — `bitsmithy-auth-ruby` package + `bitsmithy/auth-ruby` repo). Rejected because it requires fighting the namespace convention in Ruby and creates package/import-name divergence in Python (`bitsmithy-auth-python` package, `bitsmithy_auth_python` import).

This decision binds all three repos and is hard to reverse once any of them is published — renaming would break every host app's Gemfile entry. Recording it here so future contributors to `auth-python` and `auth-go` don't accidentally diverge from the pattern.
