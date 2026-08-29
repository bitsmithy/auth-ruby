# frozen_string_literal: true

require_relative "../engine_helper"
require "generators/bitsmithy/auth/install_generator"
require "tmpdir"

class InstallGeneratorTest < Rails::Generators::TestCase
  destination File.join(Dir.tmpdir, "bitsmithy-auth-generator-#{Process.pid}")
  setup :prepare_destination
  setup :create_routes_file
  teardown :remove_destination
  tests Bitsmithy::Auth::Generators::InstallGenerator

  test "creates initializer for the stateless host contract" do
    run_generator
    assert_file "config/initializers/bitsmithy_auth.rb" do |content|
      assert_match(/envelope_key/, content)
      assert_match(/google_client_id/, content)
      assert_match(/apple_client_id/, content)
      assert_match(/passkey_relying_party_id/, content)
      assert_match(/on_authenticated/, content)
      refute_match(/Twilio|phone|signing_key/, content)
    end
  end

  test "creates the provider choice template" do
    run_generator
    assert_file "app/views/bitsmithy/auth/federated_authentications/new.html.erb" do |content|
      assert_match(/apple_authentication_path/, content)
      assert_match(/google_authentication_path/, content)
      assert_match(/new_email_magic_link_path/, content)
    end
  end

  test "inserts the mount line once" do
    2.times { run_generator }
    assert_file "config/routes.rb" do |content|
      assert_equal 1, content.scan("mount Bitsmithy::Auth::Engine").size
    end
  end

  test "does not overwrite existing files without force" do
    run_generator
    initializer = File.join(destination_root, "config/initializers/bitsmithy_auth.rb")
    existing_content = File.read(initializer)
    run_generator

    assert_file "config/initializers/bitsmithy_auth.rb", existing_content
  end

  test "force flag overwrites existing files" do
    run_generator
    initializer = File.join(destination_root, "config/initializers/bitsmithy_auth.rb")
    File.write(initializer, "# custom content\n")
    run_generator ["--force"]

    assert_file "config/initializers/bitsmithy_auth.rb" do |content|
      assert_match(/envelope_key/, content)
      refute_match(/custom content/, content)
    end
  end

  private

  def remove_destination
    FileUtils.rm_rf(self.class.destination_root)
  end

  def create_routes_file
    root = self.class.destination_root
    FileUtils.mkdir_p(File.join(root, "config"))
    File.write(File.join(root, "config/routes.rb"), <<~RUBY)
      Rails.application.routes.draw do
        get "/up" => "health#show"
      end
    RUBY
  end
end
