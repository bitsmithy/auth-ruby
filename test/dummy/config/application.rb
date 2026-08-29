# frozen_string_literal: true

require "rails"
require "action_controller/railtie"
require "action_mailer/railtie"

require "bitsmithy/auth"

module Dummy
  class Application < Rails::Application
    config.load_defaults "8.1"
    config.secret_key_base = "dummy-secret-key-base-for-testing"
    config.eager_load = false
    config.hosts.clear
    config.action_controller.allow_forgery_protection = false
    config.action_mailer.delivery_method = :test
    config.active_job.queue_adapter = :test

    config.cache_store = :memory_store

    # Point Rails.root at the dummy app so config/routes.rb is found
    config.root = File.expand_path("..", __dir__)
  end
end
