# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

# Framework-agnostic unit tests (no Rails boot required)
Minitest::TestTask.create(:unit) do |t|
  t.test_globs = ["test/bitsmithy/**/test_*.rb"]
end

# Rails engine integration tests (boots a full Rails app)
Minitest::TestTask.create(:engine) do |t|
  t.test_globs = ["test/engine/**/test_*.rb"]
end

require "rubocop/rake_task"

RuboCop::RakeTask.new

namespace :test do
  desc "Run framework-agnostic unit tests"
  task :announce_unit do
    puts "\n=== Unit tests (framework-agnostic) ==="
  end

  desc "Run Rails engine integration tests"
  task :announce_engine do
    puts "\n=== Engine integration tests (full Rails) ==="
  end
end

desc "Run framework-agnostic unit tests with announce banner"
task unit: "test:announce_unit"
desc "Run Rails engine integration tests with announce banner"
task engine: "test:announce_engine"

desc "Run all tests (unit + engine)"
task test: %i[unit engine]

task default: %i[test rubocop]
