module Wibawa
  # A page of your own inside the admin: its own menu entry, your content,
  # and buttons that run a block. No controller or route to write.
  #
  #   Wibawa.page :maintenance do
  #     title "Maintenance"
  #     menu group: "System", icon: "cog"
  #
  #     view "admin/maintenance"                    # a template in your app, or:
  #     content { tag.p("Jobs waiting: #{Job.pending.count}") }
  #
  #     action :clear_cache, confirm: "Clear the cache?" do
  #       Rails.cache.clear
  #       "Cache cleared"
  #     end
  #   end
  class Page
    attr_reader :key, :actions, :content_block

    def initialize(name, &block)
      @key = name.to_s
      @actions = []
      @menu = {}
      instance_eval(&block) if block
    end

    def title(value = nil)
      value ? @title = value : (@title || Util.humanize(key))
    end

    def description(value = nil)
      value ? @description = value : @description
    end

    #   menu group: "System", icon: "cog"
    def menu(**options)
      @menu = options
    end

    # A template in the host app (app/views/<path>.html.erb), rendered inside the admin layout.
    def view(path = nil)
      path ? @view = path : @view
    end

    # A block run in the view (helpers available); what it returns is the page body.
    def content(&block)
      @content_block = block
    end

    # A button in the page header. The block runs in the controller on POST;
    # return a string to use it as the flash message.
    def action(name, label: nil, confirm: nil, destructive: false, &block)
      @actions << Action.new(name.to_sym, { label: label, confirm: confirm, destructive: destructive }.compact, block)
    end

    def find_action(name) = actions.find { |action| action.name.to_s == name.to_s }
    def menu_group = @menu[:group]
    def menu_icon = @menu[:icon] || "file"
  end
end
