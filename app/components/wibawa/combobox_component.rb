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
    # search when it has one, otherwise on its display-name columns (or, failing
    # those, every text column).
    def self.search(klass, scope, term)
      term = term.to_s.strip
      resource = Wibawa.registry.for_model(klass)
      scope = if term.empty?
                scope
              elsif resource&.search_fields.present?
                Wibawa::Query.new(resource, scope, { search: term }).filtered_base
              else
                text = klass.columns.select { |c| %i[string text citext].include?(c.type) }.map(&:name)
                columns = Wibawa.config.display_name_methods.map(&:to_s) & text
                columns = text if columns.empty? # no name-like column: search every text column
                like = "%#{ActiveRecord::Base.sanitize_sql_like(term)}%"
                matches = columns.map { |c| klass.arel_table[c].matches(like, "\\", false) }
                matches << klass.arel_table[klass.primary_key].eq(term) if term.match?(/\A\d+\z/)
                matches.empty? ? scope.none : scope.where(matches.reduce { |a, b| a.or(b) })
              end
      scope.reorder(klass.primary_key => :desc).limit(RESULTS)
    end

    # `value` is one id, or an array of ids with `multiple: true`.
    def initialize(name:, klass:, value:, resource_key:, id:, form: nil, input_html: {}, multiple: false)
      @name = name
      @klass = klass
      @value = value
      @resource_key = resource_key
      @id = id
      @form = form
      @input_html = input_html
      @multiple = multiple
    end

    def call
      label = current ? presenter.display_name(current) : ("##{@value}" if @value.present?) unless @multiple
      data = { wb_combobox: true, url: helpers.options_resource_path(resource: @resource_key, target: @klass.name), multiple: @multiple || nil }
      content_tag(:div, class: "relative", data: data) do
        safe_join([
          (@multiple ? chips_html : hidden_input(@value)),
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

    def hidden_input(value) = helpers.tag.input(type: "hidden", name: @name, value: value, form: @form)

    # The blank input lets an empty selection reach the server; the template is
    # what wibawa.js copies when a record is picked.
    def chips_html
      safe_join([
        hidden_input(""),
        content_tag(:ul, safe_join(chosen.map { |label, id| chip(label, id) }), class: "mb-2 flex flex-wrap gap-2 empty:hidden", data: { wb_combo_chips: true }),
        content_tag(:template, chip("", ""), data: { wb_combo_chip_template: true })
      ])
    end

    def chip(label, id)
      content_tag(:li, class: "inline-flex max-w-full items-center gap-1 rounded-control bg-surface-2 py-1 pl-2.5 pr-1 text-sm text-ink ring-1 ring-line") do
        safe_join([
          content_tag(:span, label, class: "truncate"),
          hidden_input(id),
          content_tag(:button, icon("x", size: "size-3.5"), type: "button", data: { wb_combo_remove: true },
                               class: "rounded p-1 text-ink-3 hover:text-ink", "aria-label": "#{t('wibawa.form.remove')}: #{label}")
        ])
      end
    end

    # [[label, id], ...] for every chosen id. Ids outside the user's scope stay
    # chosen (saving must not drop them) but are shown as #id, not by name.
    def chosen
      ids = Array(@value).compact_blank
      visible = authorized_scope(@klass).where(@klass.primary_key => ids).index_by { |record| record.id.to_s }
      ids.map { |id| [visible[id.to_s] ? presenter.display_name(visible[id.to_s]) : "##{id}", id] }
    end

    # Looked up inside the user's scope, so an id typed into the URL is never
    # answered with the name of a record they may not see.
    def current
      return @current if defined?(@current)

      @current = @value.present? ? authorized_scope(@klass).find_by(@klass.primary_key => @value) : nil
    end
  end
end
