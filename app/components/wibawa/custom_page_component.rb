module Wibawa
  # A `Wibawa.page`: its header with the page's actions, around the content
  # the app wrote (given as this component's block).
  class CustomPageComponent < BaseComponent
    def initialize(page:)
      @page = page
    end

    attr_reader :page

    def title = page.title
    def subtitle = page.description

    def actions
      page.actions.select { |action| wibawa_authorized?(action.name, page) }.map do |action|
        { label: action.label, icon: "bolt", method: :post, confirm: action.confirm, style: action.destructive? ? :danger : :secondary,
          url: helpers.page_action_path(page: page.key, page_action: action.name) }
      end
    end
  end
end
