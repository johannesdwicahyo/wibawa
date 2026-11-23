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

      def mount_engine
        route %(mount Wibawa::Engine, at: "#{options[:path]}")
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
      end

      private

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
