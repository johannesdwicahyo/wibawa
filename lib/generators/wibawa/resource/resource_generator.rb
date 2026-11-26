require "rails/generators"

module Wibawa
  module Generators
    # bin/rails g wibawa:resource Order
    class ResourceGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      def create_resource_file
        template "resource.rb.tt", File.join("app/wibawa", "#{file_path.tr('/', '_').pluralize}.rb")
      end

      def report_secret_columns
        return unless model.respond_to?(:column_names)

        left_out = model.column_names.select { |name| Wibawa::Resource.secret?(model, name) }
        say "  left out of #{class_name}, as they look secret: #{left_out.join(', ')}", :yellow if left_out.any?
      rescue StandardError
        nil
      end

      private

      # A decimal column with one of these words in its name is shown as money.
      MONEY = /(\A|_)(total|subtotal|price|amount|cost|fee|balance|revenue)(\z|_)/

      def model
        @model ||= class_name.safe_constantize
      end

      def columns
        return [] unless model.respond_to?(:columns)

        belongs_to = model.reflect_on_all_associations(:belongs_to).to_h { |r| [ r.foreign_key.to_s, r.name.to_s ] }
        model.columns.reject { |c| c.name.match?(Wibawa::Resource::HIDDEN_ATTRIBUTES) || Wibawa::Resource.secret?(model, c.name) || (c.name.end_with?("_type") && belongs_to.key?(c.name.sub(/_type\z/, "_id"))) }
                     .map { |c| [ belongs_to.fetch(c.name, c.name), c.type ] }
      rescue StandardError
        []
      end

      def index_columns
        columns.reject { |_, type| %i[text json jsonb binary].include?(type) }.first(6).map do |name, type|
          if type == :decimal && name.match?(MONEY) then "#{name}, as: :money"
          elsif %i[integer bigint].include?(type) && name.end_with?("_cents") then "#{name}, as: :cents"
          else name
          end
        end
      end

      def searchable
        columns.select { |name, type| %i[string citext].include?(type) }.first(3).map(&:first)
      end

      def filters
        columns.filter_map do |name, type|
          if model.reflect_on_association(name.to_sym) || model.defined_enums.key?(name) then [ name, nil ]
          elsif %i[date datetime].include?(type) then [ name, "date_range" ]
          elsif type == :boolean then [ name, nil ]
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
