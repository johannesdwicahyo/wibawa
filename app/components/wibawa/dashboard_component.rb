module Wibawa
  class DashboardComponent < BaseComponent
    def initialize(dashboard:)
      @dashboard = dashboard
    end

    attr_reader :dashboard

    def custom? = dashboard.present?

    def stat_value(stat)
      value = helpers.instance_exec(&stat.block)
      return value if value.is_a?(ActiveSupport::SafeBuffer)

      presenter.format(value, stat.options[:as] || (value.is_a?(Numeric) ? :number : nil))
    end

    def stat_link(stat)
      link = stat.options[:link]
      link.is_a?(Proc) ? helpers.instance_exec(&link) : link
    end

    def table_records(table) = helpers.instance_exec(&table.block).to_a

    def table_resource(table)
      table.options[:resource] && Wibawa.registry[table.options[:resource]]
    end

    def table_columns(table)
      return table.builder.columns if table.builder

      res = table_resource(table)
      cols = res ? res.index_columns.first(5) : [ Wibawa::Column.new(:id, {}, nil) ]
      cols.map.with_index { |c, i| i.zero? ? Wibawa::Column.new(c.name, c.options.merge(link: true), c.block) : c }
    end

    def table_all_url(table)
      res = table_resource(table)
      res && wibawa_authorized?(:index, res.model) ? resources_path(resource: res.key) : nil
    end

    # Default dashboard: a card per resource the user can open.
    def resources
      Wibawa.registry.select { |r| r.menu? && r.action?(:index) && wibawa_authorized?(:index, r.model) }
                     .sort_by { |r| [ r.menu_priority, r.label.to_s ] }
    end
  end
end
