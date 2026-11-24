module Wibawa
  # A searchable select for a belongs_to with too many records to list: a text
  # box that asks the server for matches, and a hidden input holding the id.
  # Used by form fields and filters; wibawa.js drives it.
  class ComboboxComponent < BaseComponent
    # Up to this many records a plain <select> is used instead.
    THRESHOLD = 100
    RESULTS = 20

    def self.needed?(klass) = klass.limit(THRESHOLD + 1).count > THRESHOLD

    # Records of `klass` matching `term`: through the model's own resource
    # search when it has one, otherwise on its display-name columns.
    def self.search(klass, scope, term)
      term = term.to_s.strip
      resource = Wibawa.registry.for_model(klass)
      scope = if term.empty?
                scope
              elsif resource&.search_fields.present?
                Wibawa::Query.new(resource, scope, { search: term }).filtered_base
              else
                columns = Wibawa.config.display_name_methods.map(&:to_s).select { |c| %i[string text citext].include?(klass.columns_hash[c]&.type) }
                like = "%#{ActiveRecord::Base.sanitize_sql_like(term)}%"
                matches = columns.map { |c| klass.arel_table[c].matches(like, "\\", false) }
                matches << klass.arel_table[klass.primary_key].eq(term) if term.match?(/\A\d+\z/)
                matches.empty? ? scope.none : scope.where(matches.reduce { |a, b| a.or(b) })
              end
      scope.reorder(klass.primary_key => :desc).limit(RESULTS)
    end

    def initialize(name:, klass:, value:, resource_key:, id:, form: nil, input_html: {})
      @name = name
      @klass = klass
      @value = value
      @resource_key = resource_key
      @id = id
      @form = form
      @input_html = input_html
    end

    def call
      label = current ? presenter.display_name(current) : ("##{@value}" if @value.present?)
      content_tag(:div, class: "relative", data: { wb_combobox: true, url: helpers.options_resource_path(resource: @resource_key, target: @klass.name) }) do
        safe_join([
          helpers.tag.input(type: "hidden", name: @name, value: @value, form: @form),
          helpers.tag.input(**{ type: "text", id: @id, value: label, role: "combobox", autocomplete: "off", spellcheck: "false",
                                "aria-expanded": "false", "aria-controls": "#{@id}_list", "aria-autocomplete": "list",
                                placeholder: t("wibawa.combobox.placeholder"), data: { label: label.to_s },
                                class: wibawa_input_class }.merge(@input_html)),
          content_tag(:ul, "", id: "#{@id}_list", role: "listbox", hidden: true,
                               class: "absolute inset-x-0 top-full z-30 mt-1 max-h-60 overflow-y-auto rounded-control bg-surface p-1 shadow-lg ring-1 ring-line")
        ])
      end
    end

    private

    # Looked up inside the user's scope, so an id typed into the URL is never
    # answered with the name of a record they may not see.
    def current
      return @current if defined?(@current)

      @current = @value.present? ? authorized_scope(@klass).find_by(@klass.primary_key => @value) : nil
    end
  end
end
