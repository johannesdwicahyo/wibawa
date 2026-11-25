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

    MENU_ITEM = "flex w-full cursor-pointer items-center gap-2 rounded-control px-3 py-2.5 text-left text-sm hover:bg-surface-2".freeze

    # On phones, two or more secondary actions fold into a menu next to the primary one.
    def primary = @primary ||= actions.find { |action| action[:style].to_s == "primary" }
    def overflow = @overflow ||= (actions - [ primary ]).then { |rest| rest.size >= 2 ? rest : [] }

    def action_button(action, menu: false)
      style = action[:style] || :secondary
      content = helpers.safe_join([ action[:icon] && icon(action[:icon], size: "size-4"), action[:label] ].compact)
      method = (action[:method] || :get).to_sym
      css = menu ? class_names(MENU_ITEM, style.to_s == "danger" ? "text-danger" : "text-ink") : wibawa_button_class(style)

      if method == :get
        helpers.link_to(content, action[:url], class: css, data: action[:data])
      else
        form_data = action[:confirm] ? { turbo_confirm: action[:confirm] } : {}
        helpers.button_to(content, action[:url], method: method, class: css, form: { data: form_data, class: "contents" })
      end
    end
  end
end
