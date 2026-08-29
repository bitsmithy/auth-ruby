# frozen_string_literal: true

module Bitsmithy
  module Auth
    module Generators
      class InstallGenerator < Rails::Generators::Base
        source_root File.expand_path("templates", __dir__)

        def install
          template "initializer.rb.erb", "config/initializers/bitsmithy_auth.rb"
          template "federated_authentications/new.html.erb",
                   "app/views/bitsmithy/auth/federated_authentications/new.html.erb"
          %w[new sent error exchange].each do |name|
            template "email_magic_links/#{name}.html.erb",
                     "app/views/bitsmithy/auth/email_magic_links/#{name}.html.erb"
          end
          insert_mount_line
        end

        private

        def insert_mount_line
          mount_line = '  mount Bitsmithy::Auth::Engine => "/auth"'
          routes_file = "config/routes.rb"

          in_root do
            routes = File.read(routes_file)
            return if routes.include?(mount_line)

            inject_into_file routes_file,
                             "#{mount_line}\n",
                             after: /\.routes\.draw do\s*$/
          end
        end
      end
    end
  end
end
