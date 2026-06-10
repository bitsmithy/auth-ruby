# frozen_string_literal: true

require_relative "../engine_helper"
require "generators/bitsmithy/auth/install_generator"

class InstallGeneratorTest < Rails::Generators::TestCase
  destination File.expand_path("../tmp", __dir__)
  setup :prepare_destination
  setup :create_routes_file
  tests Bitsmithy::Auth::Generators::InstallGenerator

  def create_routes_file
    root = self.class.destination_root
    FileUtils.mkdir_p(File.join(root, "config"))
    File.write(File.join(root, "config/routes.rb"), <<~RUBY)
      Rails.application.routes.draw do
        get "/up" => "health#show"
      end
    RUBY
  end

  test "generator class exists" do
    assert(defined?(Bitsmithy::Auth::Generators::InstallGenerator))
  end

  test "generator inherits from Rails::Generators::Base" do
    assert_equal Rails::Generators::Base,
                 Bitsmithy::Auth::Generators::InstallGenerator.superclass
  end

  test "generator has a source_root pointing to templates directory" do
    path = Bitsmithy::Auth::Generators::InstallGenerator.source_root

    assert path.end_with?("templates")
    assert File.directory?(path)
  end

  test "creates initializer with production configuration" do
    run_generator
    assert_file "config/initializers/bitsmithy_auth.rb" do |content|
      assert_match(/signing_key.*ENV\.fetch/, content)
      assert_match(/if Rails\.env\.production\?/, content)
      assert_match(/require.*twilio_adapter/, content)
      assert_match(/twilio_account_sid.*ENV\.fetch/, content)
    end
  end

  test "creates initializer with test mode guard" do
    run_generator
    assert_file "config/initializers/bitsmithy_auth.rb" do |content|
      assert_match(/else\s*\n\s*Bitsmithy::Auth\.test_mode!/, content)
    end
  end

  test "creates initializer with commented optional overrides" do
    run_generator
    assert_file "config/initializers/bitsmithy_auth.rb" do |content|
      assert_match(/# c\.after_sign_in_path/, content)
      assert_match(/# c\.after_sign_out_path/, content)
      assert_match(/# c\.sign_in_path/, content)
      assert_match(/# c\.on_verified/, content)
    end
  end

  test "creates phone form template" do
    run_generator
    assert_file "app/views/bitsmithy/auth/sessions/new.html.erb" do |content|
      assert_match(/send_code_path/, content)
      assert_match(/@error/, content)
      assert_match(/telephone_field_tag/, content)
    end
  end

  test "creates code form template" do
    run_generator
    assert_file "app/views/bitsmithy/auth/sessions/edit.html.erb" do |content|
      assert_match(/verify_path/, content)
      assert_match(/@phone/, content)
      assert_match(/@error/, content)
      assert_match(/text_field_tag.*:code/, content)
    end
  end

  test "inserts mount line into routes" do
    run_generator
    assert_file "config/routes.rb" do |content|
      assert_match(/mount Bitsmithy::Auth::Engine/, content)
    end
  end

  test "does not duplicate mount line on second run" do
    2.times { run_generator }
    assert_file "config/routes.rb" do |content|
      assert_equal 1, content.scan("mount Bitsmithy::Auth::Engine").size
    end
  end

  test "does not overwrite existing files without force" do
    run_generator
    existing_content = File.read(File.join(destination_root, "config/initializers/bitsmithy_auth.rb"))
    run_generator

    assert_file "config/initializers/bitsmithy_auth.rb", existing_content
  end

  test "force flag overwrites existing files" do
    run_generator
    File.write(File.join(destination_root, "config/initializers/bitsmithy_auth.rb"), "# custom content\n")
    run_generator ["--force"]
    assert_file "config/initializers/bitsmithy_auth.rb" do |content|
      assert_match(/signing_key.*ENV/, content)
      refute_match(/custom content/, content)
    end
  end
end
