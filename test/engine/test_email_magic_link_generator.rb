# frozen_string_literal: true

require_relative "../engine_helper"
require "generators/bitsmithy/auth/install_generator"

class EmailMagicLinkGeneratorTest < Rails::Generators::TestCase
  destination File.expand_path("../tmp", __dir__)
  setup :prepare_destination
  setup :create_routes_file
  tests Bitsmithy::Auth::Generators::InstallGenerator

  def test_creates_email_magic_link_host_templates
    run_generator
    assert_file "app/views/bitsmithy/auth/email_magic_links/new.html.erb" do |content|
      assert_match(/email_magic_links_path/, content)
      assert_match(/email_field_tag/, content)
    end
    assert_file "app/views/bitsmithy/auth/email_magic_links/exchange.html.erb" do |content|
      assert_match(/verify_email_magic_link_path/, content)
      assert_match(/location\.hash/, content)
    end
  end

  private

  def create_routes_file
    root = self.class.destination_root
    FileUtils.mkdir_p(File.join(root, "config"))
    File.write(File.join(root, "config/routes.rb"), <<~RUBY)
      Rails.application.routes.draw do
      end
    RUBY
  end
end
