module Wibawa
  # One form field: label, input, hint and errors. The input type is inferred
  # from the model (column type, enum, association, attachment) unless `as:` is set.
  class FieldComponent < BaseComponent
    TEXT_INPUTS = {
      string: :text_field, email: :email_field, password: :password_field, tel: :telephone_field,
      url: :url_field, color: :color_field, search: :search_field
    }.freeze
    COLLECTION_LIMIT = 500

    def initialize(form:, field:, klass:, compact: false)
      @form = form
      @field = field
      @klass = klass
      @compact = compact
    end

    attr_reader :form, :field, :klass

    def call
      type = input_type
      return form.hidden_field(attribute) if type == :hidden

      content_tag(:div, class: class_names("min-w-0", width_class(type) => !@compact), data: { wb_field: field.name }) do
        parts = type == :boolean ? [ boolean_html ] : [ label_html, input_html(type) ]
        safe_join((parts + [ hint_html, error_html ]).compact)
      end
    end

    def record = form.object
    def name = field.name

    def input_type
      @input_type ||= begin
        explicit = field.as&.to_sym
        explicit || inferred_type
      end
    end

    def reflection
      return @reflection if defined?(@reflection)

      @reflection = klass.respond_to?(:reflect_on_association) ? klass.reflect_on_association(name) : nil
    end

    def attachment
      return @attachment if defined?(@attachment)

      @attachment = klass.respond_to?(:reflect_on_attachment) ? klass.reflect_on_attachment(name) : nil
    end

    # The attribute the input writes to (belongs_to writes the foreign key).
    def attribute
      return reflection.foreign_key.to_sym if reflection&.macro == :belongs_to
      return :"#{Util.singularize(name)}_ids" if reflection && %i[has_many has_and_belongs_to_many].include?(reflection.macro)

      name
    end

    def errors
      return [] unless record.respond_to?(:errors)

      (record.errors[attribute] + (attribute == name ? [] : record.errors[name])).uniq
    end

    def required?
      return false unless klass.respond_to?(:validators_on)

      klass.validators_on(name, attribute).any? { |v| v.kind == :presence && v.options.slice(:if, :unless, :on).empty? }
    end

    private

    def inferred_type
      return :attachment if attachment
      return :rich_text if klass.respond_to?(:reflect_on_association) && klass.reflect_on_association(:"rich_text_#{name}")
      return :select if field.options[:collection]

      if reflection
        return :belongs_to if reflection.macro == :belongs_to && !reflection.polymorphic?
        return :many if %i[has_many has_and_belongs_to_many].include?(reflection.macro)
      end
      return :select if klass.respond_to?(:defined_enums) && klass.defined_enums.key?(name.to_s)

      column = klass.respond_to?(:columns_hash) ? klass.columns_hash[attribute.to_s] : nil
      case column&.type
      when :text then :text
      when :json, :jsonb then :json
      when :integer, :bigint, :decimal, :float then :number
      when :boolean then :boolean
      when :date then :date
      when :datetime, :timestamp, :timestamptz then :datetime
      when :time then :time
      else string_flavor
      end
    end

    def string_flavor
      n = name.to_s
      return :password if n.include?("password")
      return :email if n.include?("email")
      return :tel if n.match?(/phone|mobile|whatsapp|\btel/)
      return :url if n.match?(/url|website/)

      :string
    end

    def label_text
      field.options[:label] || (klass.respond_to?(:human_attribute_name) ? klass.human_attribute_name(name) : Util.humanize(name))
    end

    def label_html
      text = required? ? safe_join([ label_text, content_tag(:span, " *", class: "text-danger", "aria-hidden": "true") ]) : label_text
      form.label(attribute, text, class: label_class)
    end

    def label_class
      @compact ? "mb-1 block text-xs font-medium text-ink-2" : "mb-1.5 block text-sm font-medium text-ink"
    end

    def html_options(extra = {})
      { class: wibawa_input_class(errors.any?), "aria-invalid": (errors.any? ? "true" : nil),
        "aria-describedby": (errors.any? ? error_id : nil),
        required: (required? && !%i[attachment boolean].include?(input_type) ? true : nil) }
        .merge(extra).merge(field.options[:input_html] || {}).compact
    end

    def input_html(type)
      custom = Wibawa.config.field_types[type]
      return helpers.instance_exec(form, attribute, html_options, &custom) if custom

      case type
      when *TEXT_INPUTS.keys
        extra = type == :password ? { autocomplete: "new-password" } : {}
        form.public_send(TEXT_INPUTS[type], attribute, html_options(extra))
      when :text then form.text_area(attribute, html_options(rows: field.options[:rows] || 4))
      when :json then form.text_area(attribute, html_options(rows: 8, value: json_value, class: "#{wibawa_input_class(errors.any?)} font-mono text-xs"))
      when :number then form.number_field(attribute, html_options(step: number_step))
      when :date then form.date_field(attribute, html_options)
      when :datetime then form.datetime_field(attribute, html_options)
      when :time then form.time_field(attribute, html_options)
      when :select then form.select(attribute, select_options, { include_blank: blank_option }, html_options)
      when :belongs_to then searchable? ? combobox_html : form.select(attribute, belongs_to_options, { include_blank: blank_option }, html_options)
      when :many then searchable? ? combobox_html(multiple: true) : many_select_html
      when :rich_text then rich_text_html
      when :attachment then attachment_html
      else form.text_field(attribute, html_options)
      end
    end

    def boolean_html
      content_tag(:div, class: "flex items-start gap-3") do
        safe_join([
          form.check_box(attribute, class: "mt-0.5 size-4 rounded border-line accent-[var(--color-primary)]"),
          form.label(attribute, label_text, class: "text-sm font-medium text-ink")
        ])
      end
    end

    def rich_text_html
      # Through the view, not the form builder: the builder would look for Action Text's tag helper on this component.
      if helpers.respond_to?(:rich_text_area)
        load_editor
        helpers.rich_text_area(form.object_name, attribute, object: record, id: form.field_id(attribute), class: "wb-trix")
      else
        form.text_area(attribute, html_options(rows: 6))
      end
    end

    # Action Text ships the editor (Trix) as assets; the admin layout does not
    # know about them, so the first rich text field on a page adds them to <head>.
    def load_editor
      return if helpers.content_for?(:wibawa_editor)

      helpers.content_for(:wibawa_editor, "loaded")
      helpers.content_for(:head, safe_join([ helpers.stylesheet_link_tag("trix", "data-turbo-track": "reload"),
                                            helpers.javascript_include_tag("trix", "actiontext", defer: true, "data-turbo-track": "reload") ]))
    end

    def attachment_html
      many = attachment.macro == :has_many_attached
      current = record.public_send(name)
      input = form.file_field(attribute, multiple: many, class: "block w-full text-sm text-ink-2 " \
                                                            "file:mr-3 file:rounded-control file:border-0 file:bg-surface-2 file:px-3 file:py-2 " \
                                                            "file:text-sm file:font-semibold file:text-ink hover:file:bg-line " \
                                                            "")
      return input unless current.attached?

      existing = content_tag(:div, presenter.format(current, nil, record: record), class: "mb-2 text-sm")
      safe_join([ existing, input ])
    end

    def number_step
      type = klass.respond_to?(:columns_hash) ? klass.columns_hash[attribute.to_s]&.type : nil
      %i[integer bigint].include?(type) ? 1 : "any"
    end

    def json_value
      value = record.public_send(attribute)
      value.is_a?(String) ? value : (value.nil? ? "" : JSON.pretty_generate(value))
    end

    def blank_option
      required? && !record.public_send(attribute).nil? ? false : t("wibawa.form.select_blank")
    end

    def select_options
      collection = field.options[:collection]
      collection = helpers.instance_exec(&collection) if collection.is_a?(Proc)
      collection ||= klass.defined_enums[name.to_s]&.keys || []
      collection.map { |item| item.is_a?(Array) ? item : [ Util.humanize(item.to_s), item ] }
    end

    # An association becomes a search box once its table is too long to list.
    # `searchable: true` or `false` on the field decides it by hand.
    def searchable?
      return false if field.options[:collection]

      choice = field.options[:searchable]
      choice.nil? ? Wibawa::ComboboxComponent.needed?(reflection.klass) : choice
    end

    def combobox_html(multiple: false)
      render wibawa_component(:combobox, Wibawa::ComboboxComponent).new(
        name: form.field_name(attribute, multiple: multiple), klass: reflection.klass, value: record.public_send(attribute),
        resource_key: helpers.params[:resource], id: form.field_id(attribute), multiple: multiple,
        input_html: html_options.except(*(multiple ? [ :required ] : []))
      )
    end

    # Chosen ids the list does not offer (past the limit, or outside the user's
    # scope) ride along as hidden inputs, so saving the form never drops them.
    def many_select_html
      options = many_options
      offered = options.map { |_, id| id.to_s }
      kept = Array(record.public_send(attribute)).map(&:to_s) - offered
      safe_join([ form.select(attribute, options, {}, html_options(multiple: true, size: 6)) ] +
                kept.map { |id| helpers.hidden_field_tag(form.field_name(attribute, multiple: true), id, id: nil) })
    end

    def belongs_to_options
      scope = field.options[:collection]
      scope = helpers.instance_exec(&scope) if scope.is_a?(Proc)
      records = scope || authorized_scope(reflection.klass).limit(COLLECTION_LIMIT)
      records.map { |r| r.is_a?(Array) ? r : [ presenter.display_name(r), r.id ] }
    end

    def many_options
      authorized_scope(reflection.klass).limit(COLLECTION_LIMIT).map { |r| [ presenter.display_name(r), r.id ] }
    end

    def hint_html
      hint = field.options[:hint]
      hint && content_tag(:p, hint, class: "mt-1.5 text-xs text-ink-2")
    end

    def error_id = "#{form.object_name}_#{attribute}_error".gsub(/[^\w-]+/, "_")

    # Inputs are as wide as what goes in them, not as wide as the page.
    def width_class(type)
      case type
      when :number, :date, :datetime, :time then "max-w-48"
      when :select, :belongs_to, :email, :tel, :password then "max-w-80"
      end
    end

    def error_html
      return nil if errors.empty?

      content_tag(:p, errors.to_sentence.upcase_first, id: error_id, class: "mt-1.5 text-xs font-medium text-danger")
    end
  end
end
