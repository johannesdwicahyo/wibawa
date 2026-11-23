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
      success: "bg-emerald-50 text-emerald-700 ring-emerald-600/20 dark:bg-emerald-500/10 dark:text-emerald-400 dark:ring-emerald-500/30",
      warning: "bg-amber-50 text-amber-800 ring-amber-600/20 dark:bg-amber-500/10 dark:text-amber-400 dark:ring-amber-500/30",
      danger: "bg-rose-50 text-rose-700 ring-rose-600/20 dark:bg-rose-500/10 dark:text-rose-400 dark:ring-rose-500/30",
      info: "bg-sky-50 text-sky-700 ring-sky-600/20 dark:bg-sky-500/10 dark:text-sky-400 dark:ring-sky-500/30",
      neutral: "bg-zinc-100 text-zinc-700 ring-zinc-500/20 dark:bg-zinc-500/10 dark:text-zinc-300 dark:ring-zinc-500/30"
    }.freeze
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
      when ActiveRecord::Base then display_name(value)
      when ActiveSupport::SafeBuffer then view.strip_tags(value).squish
      when Time then value.strftime("%Y-%m-%d %H:%M:%S")
      when Date then value.iso8601
      when Array then value.map { |v| v.is_a?(ActiveRecord::Base) ? display_name(v) : v.to_s }.join(", ")
      when Hash then value.to_json
      else
        if defined?(ActionText::RichText) && value.is_a?(ActionText::RichText)
          value.to_plain_text
        elsif value.respond_to?(:attached?)
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

    def empty
      view.tag.span("—", class: "text-zinc-400 dark:text-zinc-600")
    end

    private

    def link_class = "font-medium text-primary hover:underline underline-offset-2"

    def auto(value, record:, name:)
      case value
      when true, false then boolean(value)
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
          badge(value)
        elsif defined?(ActionText::RichText) && value.is_a?(ActionText::RichText)
          view.truncate(value.to_plain_text, length: 80)
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
      links << view.tag.span("…", class: "text-zinc-400") if more
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
      if value
        badge(view.t("wibawa.yes", default: "Yes"), color: :success)
      else
        badge(view.t("wibawa.no", default: "No"), color: :neutral)
      end
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
      src = value.respond_to?(:attached?) ? (value.attached? ? view.url_for(value) : nil) : value.to_s
      return empty if src.blank?

      view.image_tag(src, class: "h-10 w-10 rounded-md object-cover ring-1 ring-zinc-950/10 dark:ring-white/10", loading: "lazy", alt: "")
    end

    def attachment(value)
      return empty unless value.attached?

      if value.respond_to?(:attachments)
        view.t("wibawa.files", count: value.attachments.size, default: "%{count} files")
      elsif value.image?
        image(value)
      else
        view.link_to(value.filename.to_s, view.url_for(value), class: link_class, target: "_blank", rel: "noopener")
      end
    end

    def attachment_names(value)
      value.respond_to?(:attachments) ? value.attachments.map { |a| a.filename.to_s }.join(", ") : value.filename.to_s
    end

    def json(value)
      view.tag.pre(JSON.pretty_generate(value.as_json), class: "max-h-64 overflow-auto rounded-md bg-zinc-50 p-3 text-xs dark:bg-zinc-900")
    end
  end
end
