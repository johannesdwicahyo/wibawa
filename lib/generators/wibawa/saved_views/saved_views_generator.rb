require "rails/generators"
require "rails/generators/active_record"
require "generators/wibawa/key_type"

module Wibawa
  module Generators
    # bin/rails g wibawa:saved_views
    class SavedViewsGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration
      include Wibawa::Generators::KeyType

      source_root File.expand_path("templates", __dir__)

      def create_migration_file
        migration_template "migration.rb.tt", "db/migrate/create_wibawa_saved_views.rb"
      end

      def show_next_steps
        say ""
        say "Next:", :green
        say "  1. bin/rails db:migrate"
        say "  2. Add `config.saved_views = true` to config/initializers/wibawa.rb"
      end
    end
  end
end
