require "rails/generators"

module Wibawa
  module Generators
    # bin/rails g wibawa:resource Order
    class ResourceGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      def create_resource_file
        template "resource.rb.tt", File.join("app/wibawa", "#{file_path.tr('/', '_').pluralize}.rb")
      end

      private

      SKIP = /\A(id|created_at|updated_at|encrypted_.*|.*_digest|.*_token|.*_ciphertext|lock_version)\z/

      def model
        @model ||= class_name.safe_constantize
      end

      def columns
        return [] unless model.respond_to?(:columns)

        belongs_to = model.reflect_on_all_associations(:belongs_to).to_h { |r| [r.foreign_key.to_s, r.name.to_s] }
        model.columns.reject { |c| c.name.match?(SKIP) || (c.name.end_with?("_type") && belongs_to.key?(c.name.sub(/_type\z/, "_id"))) }
                     .map { |c| [belongs_to.fetch(c.name, c.name), c.type] }
      rescue StandardError
        []
      end

      def index_columns
        columns.reject { |_, type| %i[text json jsonb binary].include?(type) }.first(6).map(&:first)
      end

      def searchable
        columns.select { |name, type| %i[string citext].include?(type) && !name.match?(/password/) }.first(3).map(&:first)
      end

      def filters
        columns.filter_map do |name, type|
          if model.reflect_on_association(name.to_sym) || model.defined_enums.key?(name) then [name, nil]
          elsif %i[date datetime].include?(type) then [name, "date_range"]
          elsif type == :boolean then [name, nil]
          end
        end.first(4)
      rescue StandardError
        []
      end

      def enum_scopes
        return [] unless model.respond_to?(:defined_enums)

        enum = model.defined_enums.first
        enum ? enum.last.keys.first(4) : []
      end

      def form_fields
        columns.map(&:first)
      end
    end
  end
end
