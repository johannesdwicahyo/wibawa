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
        [ name, visible ] if visible.any?
      end
    end

    Entry = Struct.new(:label, :url, :icon, :active, :group)

    # Custom pages and reports, as [[group name or nil, [entries...]], ...].
    # Pages without a group sit right under the resources; reports without one
    # go under "Reports".
    def extra_groups
      pages = Wibawa.registry.pages.select { |page| wibawa_authorized?(:show, page) }.map do |page|
        Entry.new(page.title, helpers.page_path(page: page.key), page.menu_icon, on?("pages", :page, page.key), page.menu_group)
      end
      reports = Wibawa.registry.reports.select { |report| wibawa_authorized?(:show, report) }.map do |report|
        Entry.new(report.title, helpers.report_path(report: report.key), report.menu_icon, on?("reports", :report, report.key),
                  report.menu_group || t("wibawa.reports"))
      end
      (pages + reports).group_by(&:group).sort_by { |name, _| name ? 1 : 0 }
    end

    def on?(controller, param, key) = helpers.controller_name == controller && helpers.params[param] == key

    def active?(resource) = resource.key == @current_key
    def dashboard_active? = @current_key.empty? && helpers.controller_name == "dashboard"

    def group_class
      "mb-1 mt-6 px-2.5 text-xs font-medium text-white/70 " \
        "lg:rail:mx-2 lg:rail:my-3 lg:rail:h-px lg:rail:overflow-hidden lg:rail:bg-white/15 lg:rail:p-0 lg:rail:text-transparent"
    end

    def link_class(active)
      class_names(
        "group flex items-center gap-3 rounded-control px-2.5 py-2 text-sm font-medium transition-colors lg:rail:justify-center lg:rail:px-0",
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
