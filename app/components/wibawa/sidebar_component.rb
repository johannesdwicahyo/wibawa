module Wibawa
  class SidebarComponent < BaseComponent
    def initialize(current_key: nil)
      @current_key = current_key.to_s
    end

    def title = Wibawa.config.site_title

    # Until the app names itself, the tile shows the Wibawa mark instead of initials.
    def default_title? = title == Wibawa::Configuration.new.site_title

    def initials
      title.to_s.split(/\s+/).first(2).map { |w| w[0] }.join.upcase.presence || "A"
    end

    def groups
      Wibawa.registry.menu.filter_map do |name, resources|
        visible = resources.select { |r| visible?(r) }
        [name, visible] if visible.any?
      end
    end

    def active?(resource) = resource.key == @current_key
    def dashboard_active? = @current_key.empty? && helpers.controller_name == "dashboard"

    def link_class(active)
      class_names(
        "group flex items-center gap-3 rounded-control px-2.5 py-2 text-sm font-medium transition-colors",
        "bg-white/12 text-white" => active,
        "text-white/70 hover:bg-white/[0.07] hover:text-white" => !active
      )
    end

    def user = helpers.wibawa_current_user
    def user_label = user && presenter.display_name(user)
    def logout_path = helpers.wibawa_logout_path

    private

    def visible?(resource)
      condition = resource.menu_visible_if
      return false if condition && !helpers.instance_exec(user, &condition)

      resource.action?(:index) && wibawa_authorized?(:index, resource.model)
    end
  end
end
