# frozen_string_literal: true

require_relative "lib/bitsmithy/auth/version"

Gem::Specification.new do |spec|
  spec.name = "bitsmithy-auth"
  spec.version = Bitsmithy::Auth::VERSION
  spec.authors = ["Howard Huang"]
  spec.email = ["hao@hwrd.me"]

  spec.summary = "Phone-number OTP authentication for Ruby applications"
  spec.description = "Verify users by sending one-time codes to their phone via SMS. " \
                     "Wraps Twilio Verify, provides a Rails controller helper, and ships " \
                     "a mountable engine for the default sign-in flow."
  spec.homepage = "https://github.com/bitsmithy/auth-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 4.0.5"
  # Private gem — consumed via `gem 'bitsmithy-auth', github: 'bitsmithy/auth-ruby'`.
  # If switching to GitHub Packages or a private gem server, set allowed_push_host below.
  # spec.metadata["allowed_push_host"] = "https://rubygems.pkg.github.com/bitsmithy"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bitsmithy/auth-ruby"
  spec.metadata["changelog_uri"] = "https://github.com/bitsmithy/auth-ruby/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "jwt", "~> 3.2"
  spec.add_dependency "phonelib", "~> 0.10"
  spec.add_dependency "twilio-ruby", "~> 7.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://guides.rubygems.org/make-your-own-gem/
end
