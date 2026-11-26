require "rails/generators"

module Wibawa
  module Generators
    # bin/rails g wibawa:install [--path=/admin] [--skip-resources]
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      class_option :path, type: :string, default: "/admin", desc: "Where to mount the admin"
      class_option :skip_resources, type: :boolean, default: false, desc: "Don't generate a resource file per model"

      def create_initializer
        template "initializer.rb.tt", "config/initializers/wibawa.rb"
      end

      def create_dashboard
        template "dashboard.rb.tt", "app/wibawa/dashboard.rb"
      end

      # The mount goes last in the routes file. Under its path the engine answers
      # every URL (/ops/anything is "the resource called anything"), so a route
      # of the app's own under the same path only works if it comes first.
      def mount_engine
        line = %(  mount Wibawa::Engine, at: "#{options[:path]}"\n)
        routes = File.join(destination_root, "config/routes.rb")
        if File.exist?(routes) && File.read(routes).match?(/^end\s*\z/)
          inject_into_file "config/routes.rb", line, before: /^end\s*\z/
        else
          route line.strip
        end
      end

      def create_resources
        return if options[:skip_resources]

        model_names.each do |name|
          generate "wibawa:resource", name
        end
      end

      def show_next_steps
        say ""
        say "Wibawa is installed. Next:", :green
        say "  1. Set up authentication in config/initializers/wibawa.rb"
        say "  2. Start the server and open #{options[:path]}"
        say "  3. Edit the files in app/wibawa/ to shape each page"
        say ""
        say "Routes of your own under #{options[:path]} (a sign-in page, say) must stay above the mount line in config/routes.rb."
      end

      private

      # The Rails 8 authentication generator keeps the user in Current, and
      # defines no `current_user` method on controllers.
      def current_attributes_user?
        file = File.join(destination_root, "app/models/current.rb")
        File.exist?(file) && File.read(file).match?(/\buser\b/)
      end

      def model_names
        Dir[File.join(destination_root, "app/models/**/*.rb")].filter_map do |file|
          relative = file.delete_prefix(File.join(destination_root, "app/models/")).delete_suffix(".rb")
          next if relative.start_with?("concerns/") || relative == "application_record" || relative == "current"

          source = File.read(file)
          next unless source.match?(/<\s*(ApplicationRecord|ActiveRecord::Base)\b/)

          relative.camelize
        end.sort
      end
    end
  end
end
