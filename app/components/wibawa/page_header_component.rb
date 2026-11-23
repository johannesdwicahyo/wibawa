module Wibawa
  # Title, breadcrumbs and action buttons at the top of every page.
  #
  #   actions: [{ label: "New order", url: new_resource_path(...), style: :primary, icon: "plus" },
  #             { label: "Delete", url: ..., method: :delete, confirm: "Sure?", style: :danger }]
  class PageHeaderComponent < BaseComponent
    def initialize(title:, breadcrumbs: [], actions: [], subtitle: nil)
      @title = title
      @breadcrumbs = breadcrumbs
      @actions = actions.compact
      @subtitle = subtitle
    end

    attr_reader :title, :breadcrumbs, :actions, :subtitle

    def action_button(action)
      style = action[:style] || :secondary
      content = helpers.safe_join([action[:icon] && icon(action[:icon], size: "size-4"), action[:label]].compact)
      method = (action[:method] || :get).to_sym

      if method == :get
        helpers.link_to(content, action[:url], class: wibawa_button_class(style), data: action[:data])
      else
        form_data = action[:confirm] ? { turbo_confirm: action[:confirm] } : {}
        helpers.button_to(content, action[:url], method: method, class: wibawa_button_class(style), form: { data: form_data, class: "contents" })
      end
    end
  end
end
