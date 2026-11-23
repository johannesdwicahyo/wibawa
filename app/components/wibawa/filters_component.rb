module Wibawa
  class FiltersComponent < BaseComponent
    COLLECTION_LIMIT = 500

    def initialize(resource:, query:, form_id:, clear_url:)
      @resource = resource
      @query = query
      @form_id = form_id
      @clear_url = clear_url
    end

    attr_reader :resource, :query, :form_id, :clear_url

    def filters = resource.filters
    def model = resource.model
    def type_for(filter) = Wibawa::Query.filter_type(model, filter)

    def field_name(filter, suffix = nil) = "q[#{filter.name}#{suffix}]"
    def value(filter, suffix = nil) = query.filter_value("#{filter.name}#{suffix}")
    def field_id(filter, suffix = nil) = "wb-filter-#{filter.name}#{suffix}"

    def range_input_type(filter)
      type_for(filter) == :date_range ? "date" : "number"
    end

    def select_options(filter)
      collection = filter.options[:collection]
      collection = helpers.instance_exec(&collection) if collection.is_a?(Proc)
      return normalize(collection) if collection

      if (ref = model.reflect_on_association(filter.name))
        ref.klass.limit(COLLECTION_LIMIT).map { |r| [presenter.display_name(r), r.id] }
      elsif (enum = model.defined_enums[filter.name.to_s])
        enum.keys.map { |k| [Util.humanize(k), k] }
      else
        model.distinct.order(filter.name).limit(COLLECTION_LIMIT).pluck(filter.name).compact.map { |v| [v.to_s, v] }
      end
    end

    def boolean_options
      [[t("wibawa.yes"), "true"], [t("wibawa.no"), "false"]]
    end

    private

    def normalize(collection)
      collection.map { |item| item.is_a?(Array) ? item : [Util.humanize(item.to_s), item] }
    end
  end
end
