require "rails/generators"
require "rails/generators/active_record"

module Wibawa
  module Generators
    # bin/rails g wibawa:background_import
    class BackgroundImportGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      def create_migration_file
        migration_template "migration.rb.tt", "db/migrate/create_wibawa_imports.rb"
      end

      def show_next_steps
        say ""
        say "Next:", :green
        say "  1. bin/rails db:migrate"
        say "  2. Add `config.background_import = true` to config/initializers/wibawa.rb"
        say "  3. Make sure Active Job has a real backend (Solid Queue, Sidekiq, ...) and a worker running"
      end
    end
  end
end
