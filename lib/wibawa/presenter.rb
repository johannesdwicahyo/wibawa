module Wibawa
  # Formats attribute values for tables, show pages and CSV. Holds the view
  # context so column blocks can use any helper (link_to, number_to_currency...).
  class Presenter
    CURRENCIES = {
      "IDR" => { unit: "Rp ", precision: 0, delimiter: ".", separator: "," },
      "USD" => { unit: "$" }, "EUR" => { unit: "€" }, "GBP" => { unit: "£" },
      "SGD" => { unit: "S$" }, "AUD" => { unit: "A$" }, "MYR" => { unit: "RM " },
      "JPY" => { unit: "¥", precision: 0 }, "THB" => { unit: "฿" }, "PHP" => { unit: "₱" }
    }.freeze

    # Full class strings so Tailwind's scanner keeps them in the built CSS.
    BADGE_CLASSES = {
      success: "bg-success/10 text-success ring-success/25",
      warning: "bg-warning/10 text-warning ring-warning/25",
      danger: "bg-danger/10 text-danger ring-danger/25",
      info: "bg-info/10 text-info ring-info/25",
      neutral: "bg-surface-2 text-ink ring-line"
    }.freeze
    DOT_CLASSES = { success: "bg-success/100", warning: "bg-warning/100", danger: "bg-danger/100", info: "bg-info/100", neutral: "bg-ink-3" }.freeze
    BADGE_BASE = "inline-flex items-center rounded-md px-2 py-0.5 text-xs font-medium ring-1 ring-inset whitespace-nowrap".freeze
    STATUS_NAMES = %w[status state stage].freeze

    attr_reader :view

    def initialize(view)
      @view = view
    end

    # The value behind a column: block result or attribute.
    def raw(record, column)
      if column.block
        view.instance_exec(record, &column.block)
      elsif record.respond_to?(column.name)
        record.public_send(column.name)
      end
    end

    # HTML for a table cell or show-page row.
    def cell(record, column)
      value = raw(record, column)
      html = if column.block && value.is_a?(ActiveSupport::SafeBuffer) && column.as.nil?
               value
      else
               format(value, column.as, record: record, column: column)
      end
      column.link? ? link_to_record(record, html) : html
    end

    def format(value, as, record: nil, column: nil)
      options = column&.options || {}
      return empty if value.nil? && as&.to_sym != :boolean
      return empty if value.respond_to?(:empty?) && value.empty? && as.nil?

      case as&.to_sym
      when :money then money(value, options[:currency])
      when :badge then badge(value)
      when :status then status(value)
      when :boolean then boolean(value)
      when :date then view.l(value.to_date, format: options[:format] || :default)
      when :datetime then datetime(value, options[:format])
      when :time_ago then time_ago(value)
      when :number then number(value)
      when :percentage then view.number_to_percentage(value, precision: options.fetch(:precision, 1))
      when :email then view.mail_to(value, value, class: link_class)
      when :url then view.link_to(value, value, target: "_blank", rel: "noopener", class: link_class)
      when :image then image(value)
      when :text then view.truncate(value.to_s, length: options[:length] || 80)
      when :json then json(value)
      when :tags then view.safe_join(Array(value).map { |v| badge(v, color: :neutral) }, " ")
      else auto(value, record: record, name: column&.name)
      end
    end

    # Plain text for CSV export.
    def plain(record, column)
      value = raw(record, column)
      case value
      when nil then ""
      when rich_text_class then value.to_plain_text # before ActiveRecord::Base: a rich text is a record too
      when ActiveRecord::Base then display_name(value)
      when ActiveSupport::SafeBuffer then view.strip_tags(value).squish
      when Time then value.strftime("%Y-%m-%d %H:%M:%S")
      when Date then value.iso8601
      when Array then value.map { |v| v.is_a?(ActiveRecord::Base) ? display_name(v) : v.to_s }.join(", ")
      when Hash then value.to_json
      else
        if value.respond_to?(:attached?)
          value.attached? ? attachment_names(value) : ""
        else
          value.to_s
        end
      end
    end

    def display_name(record)
      return "" if record.nil?

      Wibawa.config.display_name_methods.each do |method|
        next unless record.respond_to?(method)

        value = record.public_send(method)
        return value.to_s if value.present?
      end
      "#{record.model_name.human} ##{record.to_param}"
    end

    # Link to the record's admin page if it has one, otherwise plain text.
    def link_to_record(record, label = nil)
      label ||= display_name(record)
      resource = resource_for(record)
      return label unless resource&.action?(:show) && view.wibawa_authorized?(:show, record)

      view.link_to(label, view.resource_path(resource: resource.key, id: record), class: link_class)
    end

    def resource_for(record)
      klass = record.class
      Wibawa.registry.for_model(klass) || (klass.respond_to?(:base_class) && Wibawa.registry.for_model(klass.base_class))
    end

    def badge(value, color: nil)
      color ||= Wibawa.config.badge_color_for(value)
      label = value.is_a?(Symbol) || value.is_a?(String) ? Util.humanize(value) : value.to_s
      view.tag.span(label, class: "#{BADGE_BASE} #{BADGE_CLASSES.fetch(color, BADGE_CLASSES[:neutral])}")
    end

    # A status in a table: colored dot plus the word in ink. Quieter than a
    # column of filled pills; use `as: :badge` when you want the pill.
    def status(value)
      label = value.is_a?(Symbol) || value.is_a?(String) ? Util.humanize(value) : value.to_s
      dot(label, Wibawa.config.badge_color_for(value))
    end

    def dot(label, color)
      mark = view.tag.span("", class: "size-1.5 shrink-0 rounded-full #{DOT_CLASSES.fetch(color, DOT_CLASSES[:neutral])}", "aria-hidden": "true")
      view.tag.span(view.safe_join([ mark, label ]), class: "flex items-center gap-2 whitespace-nowrap")
    end

    def empty
      view.tag.span("—", class: "text-ink-3")
    end

    private

    # Ink, not the accent: the accent is kept for the primary action and selection.
    def link_class = "font-medium text-ink underline-offset-4 hover:underline"

    def auto(value, record:, name:)
      case value
      when true, false then boolean(value)
      when rich_text_class then view.truncate(value.to_plain_text, length: 80)
      when ActiveRecord::Base then link_to_record(value)
      when ActiveRecord::Relation then collection(value.limit(4).to_a, more: value.size > 3)
      when Array then value.first.is_a?(ActiveRecord::Base) ? collection(value.first(4), more: value.size > 3) : value.join(", ")
      when Time then datetime(value)
      when Date then view.l(value)
      when Integer then name == :id ? view.tag.span(value, class: "tabular-nums") : number(value)
      when Numeric then number(value)
      when Hash then json(value)
      else
        if enum?(record, name) || STATUS_NAMES.include?(name.to_s)
          status(value)
        elsif value.respond_to?(:attached?)
          attachment(value)
        else
          view.truncate(value.to_s, length: 80)
        end
      end
    end

    def enum?(record, name)
      name && record.class.respond_to?(:defined_enums) && record.class.defined_enums.key?(name.to_s)
    end

    def collection(records, more:)
      links = records.first(3).map { |r| link_to_record(r) }
      links << view.tag.span("…", class: "text-ink-3") if more
      view.safe_join(links, ", ")
    end

    def money(value, currency)
      currency = (currency || Wibawa.config.currency).to_s.upcase
      text = if (formatter = Wibawa.config.money_format)
               formatter.call(value, currency, view)
      else
               view.number_to_currency(value, **CURRENCIES.fetch(currency) { { unit: "#{currency} " } })
      end
      view.tag.span(text, class: "tabular-nums whitespace-nowrap")
    end

    def number(value)
      view.tag.span(view.number_with_delimiter(value), class: "tabular-nums")
    end

    def boolean(value)
      value ? dot(view.t("wibawa.yes", default: "Yes"), :success) : dot(view.t("wibawa.no", default: "No"), :neutral)
    end

    def datetime(value, format = nil)
      return view.l(value.to_date) unless value.respond_to?(:hour)

      view.tag.time(view.l(value, format: format || :short), datetime: value.iso8601,
                                                             title: view.l(value, format: :long),
                                                             class: "whitespace-nowrap tabular-nums")
    end

    def time_ago(value)
      text = view.t("wibawa.time_ago", time: view.time_ago_in_words(value), default: "%{time} ago")
      view.tag.time(text, datetime: value.iso8601, title: view.l(value, format: :long), class: "whitespace-nowrap")
    end

    def image(value)
      src = value.respond_to?(:attached?) ? (value.attached? ? file_path(value) : nil) : value.to_s
      return empty if src.blank?

      view.image_tag(src, class: "h-10 w-10 rounded-md object-cover ring-1 ring-line", loading: "lazy", alt: "")
    end

    def attachment(value)
      return empty unless value.attached?

      if many_attached?(value)
        view.t("wibawa.files", count: value.attachments.size, default: "%{count} files")
      elsif value.image?
        image(value)
      else
        view.link_to(value.filename.to_s, file_path(value), class: link_class, target: "_blank", rel: "noopener")
      end
    end

    def attachment_names(value)
      many_attached?(value) ? value.attachments.map { |a| a.filename.to_s }.join(", ") : value.filename.to_s
    end

    # Active Storage's routes belong to the host app; from inside the engine they are reached through main_app.
    def file_path(value) = view.main_app.rails_blob_path(value, only_path: true)

    # A single attachment also answers `attachments` (it passes the call on), so ask for the class.
    def many_attached?(value) = defined?(ActiveStorage::Attached::Many) && value.is_a?(ActiveStorage::Attached::Many)

    # A class that matches nothing when Action Text is not loaded.
    def rich_text_class = defined?(ActionText::RichText) ? ActionText::RichText : NilClass

    def json(value)
      view.tag.pre(JSON.pretty_generate(value.as_json), class: "max-h-64 overflow-auto rounded-md bg-surface-2 p-3 text-xs")
    end
  end
end
