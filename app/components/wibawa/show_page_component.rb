module Wibawa
  class ShowPageComponent < BaseComponent
    def initialize(resource:, record:)
      @resource = resource
      @record = record
    end

    attr_reader :resource, :record

    def title = presenter.display_name(record)

    def breadcrumbs
      [ [ resource.label, resource.action?(:index) ? resources_path(resource: resource.key) : nil ], [ title, nil ] ]
    end

    # A row's value. Rich text is shown whole and formatted here (a table cell
    # gets a plain excerpt); Action Text sanitizes it when it renders.
    def value(column)
      rich = record.public_send(column.name) if column.block.nil? && column.as.nil? && rich_text?(column.name)
      rich.present? ? content_tag(:div, rich.to_s, class: "wb-rich") : presenter.cell(record, column)
    end

    def row_label(column)
      column.options[:label] || record.class.human_attribute_name(column.as.to_s == "cents" ? column.name.to_s.delete_suffix("_cents") : column.name)
    end

    def rich_text?(name)
      record.class.respond_to?(:rich_text_association_names) && record.class.rich_text_association_names.include?(:"rich_text_#{name}")
    end

    def header_actions
      list = resource.member_actions.filter_map do |action|
        next unless wibawa_authorized?(action.name, record)

        { label: action.label, icon: "bolt", method: action.http_method,
          style: action.destructive? ? :danger : :secondary, confirm: action.confirm,
          url: member_action_resource_path(resource: resource.key, id: record, member_action: action.name) }
      end
      if Wibawa.config.audit_log && resource.key != Wibawa::AuditEntry::RESOURCE_KEY && wibawa_authorized?(:index, Wibawa::AuditEntry)
        list << { label: t("wibawa.audit.history"), icon: "file", style: :secondary,
                  url: resources_path(resource: Wibawa::AuditEntry::RESOURCE_KEY, q: { resource_key: resource.key, record_id: record.id }) }
      end
      if resource.action?(:destroy) && wibawa_authorized?(:destroy, record)
        list << { label: t("wibawa.delete"), icon: "trash", method: :delete, style: :danger,
                  confirm: t("wibawa.confirm_delete", name: title),
                  url: resource_path(resource: resource.key, id: record) }
      end
      if resource.action?(:edit) && wibawa_authorized?(:edit, record)
        list << { label: t("wibawa.edit"), icon: "pencil", style: :primary,
                  url: edit_resource_path(resource: resource.key, id: record) }
      end
      list
    end

    # The record's PaperTrail or Audited history, if its model keeps one.
    # Only changes to attributes this page shows are listed.
    def history
      return @history if defined?(@history)

      names = resource.show_items.filter_map { |kind, column| column.name.to_s if kind == :row }
      keys = names.filter_map { |name| record.class.reflect_on_association(name)&.then { |ref| ref.foreign_key.to_s if ref.belongs_to? } }
      @history = Wibawa::ModelHistory.for(record, only: names + keys)
    end

    def history_event(entry) = t("wibawa.history.events.#{entry.event}", default: entry.event.to_s.humanize)

    # Groups consecutive :row items into one attributes card.
    def sections
      resource.show_items.slice_when { |a, b| a.first != :row || b.first != :row }.to_a
    end

    def panel_content(block) = helpers.instance_exec(record, &block)

    def association_records(name, limit)
      value = record.public_send(name)
      value = presenter.related_records(value) # only the ones this user may see
      value.respond_to?(:limit) ? value.limit(limit).to_a : Array(value).first(limit)
    end

    def association_title(name, options)
      options[:title] || record.class.human_attribute_name(name)
    end

    def association_columns(name, builder)
      return builder.columns if builder.columns.any?

      klass = record.class.reflect_on_association(name)&.klass
      related = klass && Wibawa.registry.for_model(klass)
      related ? related.index_columns.reject { |c| c.name == :created_at } : [ Wibawa::Column.new(:id, { link: true }, nil) ]
    end
  end
end
