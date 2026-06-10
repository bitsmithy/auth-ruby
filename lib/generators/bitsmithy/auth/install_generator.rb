# frozen_string_literal: true

module Bitsmithy
  module Auth
    module Generators
      class InstallGenerator < Rails::Generators::Base
        source_root File.expand_path("templates", __dir__)

        def install
          template "initializer.rb.erb", "config/initializers/bitsmithy_auth.rb"
          template "new.html.erb", "app/views/bitsmithy/auth/sessions/new.html.erb"
          template "edit.html.erb", "app/views/bitsmithy/auth/sessions/edit.html.erb"
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
