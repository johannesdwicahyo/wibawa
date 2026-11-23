module Wibawa
  class ShowPageComponent < BaseComponent
    def initialize(resource:, record:)
      @resource = resource
      @record = record
    end

    attr_reader :resource, :record

    def title = presenter.display_name(record)

    def breadcrumbs
      [[resource.label, resource.action?(:index) ? resources_path(resource: resource.key) : nil], [title, nil]]
    end

    def header_actions
      list = resource.member_actions.filter_map do |action|
        next unless wibawa_authorized?(action.name, record)

        { label: action.label, icon: "bolt", method: action.http_method,
          style: action.destructive? ? :danger : :secondary, confirm: action.confirm,
          url: member_action_resource_path(resource: resource.key, id: record, member_action: action.name) }
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

    # Groups consecutive :row items into one attributes card.
    def sections
      resource.show_items.slice_when { |a, b| a.first != :row || b.first != :row }.to_a
    end

    def panel_content(block) = helpers.instance_exec(record, &block)

    def association_records(name, limit)
      value = record.public_send(name)
      value.respond_to?(:limit) ? value.limit(limit).to_a : Array(value).first(limit)
    end

    def association_title(name, options)
      options[:title] || record.class.human_attribute_name(name)
    end

    def association_columns(name, builder)
      return builder.columns if builder.columns.any?

      klass = record.class.reflect_on_association(name)&.klass
      related = klass && Wibawa.registry.for_model(klass)
      related ? related.index_columns.reject { |c| c.name == :created_at } : [Wibawa::Column.new(:id, { link: true }, nil)]
    end
  end
end
