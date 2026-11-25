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
    def field_id(filter, suffix = nil) = "wb-filter-#{filter.name}#{suffix}".tr(".", "-")

    def range_input_type(filter)
      type_for(filter) == :date_range ? "date" : "number"
    end

    def select_options(filter) = (@select_options ||= {})[filter.name] ||= load_options(filter)

    # The model behind a belongs_to filter, when it has too many records for a <select>.
    def combobox_class(filter)
      return nil if filter.options[:collection]

      klass = choice_reflection(filter)&.klass
      klass if klass && Wibawa::ComboboxComponent.needed?(klass)
    end

    def boolean_options
      [ [ t("wibawa.yes"), "true" ], [ t("wibawa.no"), "false" ] ]
    end

    # Filters that are in effect, each with a link that removes just that one.
    def chips
      @chips ||= filters.filter_map do |filter|
        keys = [ "", "_from", "_to" ].map { |suffix| "#{filter.name}#{suffix}" }
        next unless keys.any? { |key| Array(query.filter_value(key)).any?(&:present?) }

        { label: filter.label, value: chip_value(filter), url: url_without(keys) }
      end
    end

    private

    def chip_value(filter)
      case type_for(filter)
      when :date_range, :number_range
        [ value(filter, "_from"), value(filter, "_to") ].map { |v| v.presence || "…" }.join(" – ")
      when :select
        if (target = combobox_class(filter))
          record = authorized_scope(target).find_by(target.primary_key => value(filter))
          return record ? presenter.display_name(record) : "##{value(filter)}"
        end

        labels = select_options(filter).to_h { |label, v| [ v.to_s, label ] }
        Array(value(filter)).compact_blank.map { |v| labels.fetch(v.to_s, v) }.join(", ")
      when :boolean
        t(ActiveModel::Type::Boolean.new.cast(value(filter)) ? "wibawa.yes" : "wibawa.no")
      else
        Array(value(filter)).compact_blank.join(", ")
      end
    end

    def url_without(keys)
      params = preserved_params("page")
      q = (params["q"] || {}).except(*keys)
      params = params.except("q").merge(q.empty? ? {} : { "q" => q })
      resources_path(resource: resource.key, **params.to_h.symbolize_keys)
    end

    def load_options(filter)
      collection = filter.options[:collection]
      collection = helpers.instance_exec(&collection) if collection.is_a?(Proc)
      return normalize(collection) if collection

      klass, column = Wibawa::Query.target(model, filter.name)
      if (ref = choice_reflection(filter))
        authorized_scope(ref.klass).limit(COLLECTION_LIMIT).map { |r| [ presenter.display_name(r), r.id ] }
      elsif (enum = klass.defined_enums[column])
        enum.keys.map { |k| [ Util.humanize(k), k ] }
      else
        klass.distinct.order(column).limit(COLLECTION_LIMIT).pluck(column).compact.map { |v| [ v.to_s, v ] }
      end
    end

    # The association whose records this filter chooses from, if it is one.
    def choice_reflection(filter)
      klass, column = Wibawa::Query.target(model, filter.name)
      ref = klass.reflect_on_association(column.to_sym)
      ref if ref && !ref.polymorphic? && Wibawa::Query::CHOICE_MACROS.include?(ref.macro)
    end

    def normalize(collection)
      collection.map { |item| item.is_a?(Array) ? item : [ Util.humanize(item.to_s), item ] }
    end
  end
end
