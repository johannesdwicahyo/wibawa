module Wibawa
  class Registry
    include Enumerable

    attr_accessor :dashboard

    def initialize
      clear!
    end

    def clear!
      @resources = {}
      @reports = {}
      @pages = {}
      @dashboard = nil
    end

    def register(resource)
      @resources[resource.key] = resource
    end

    def [](key) = @resources[key.to_s]

    def register_report(report)
      @reports[report.key] = report
    end

    def report(key) = @reports[key.to_s]

    def register_page(page)
      @pages[page.key] = page
    end

    def page(key) = @pages[key.to_s]
    def pages = @pages.values
    def reports = @reports.values

    def fetch(key)
      self[key] || raise(ResourceNotFound, "No Wibawa resource registered as #{key.inspect}")
    end

    def for_model(model_class)
      name = model_class.respond_to?(:name) ? model_class.name : model_class.to_s
      @resources.values.find { |r| r.model_name == name }
    end

    def each(&block) = @resources.values.each(&block)
    def size = @resources.size
    def empty? = @resources.empty?

    # [[group_name_or_nil, [resources...]], ...] sorted for the sidebar.
    def menu
      visible = select(&:menu?).sort_by { |r| [r.menu_priority, r.label.to_s] }
      groups = visible.group_by(&:menu_group)
      ungrouped = groups.delete(nil) || []
      [[nil, ungrouped]] + groups.sort_by { |name, items| [items.map(&:menu_priority).min, name.to_s] }
    end
  end
end
