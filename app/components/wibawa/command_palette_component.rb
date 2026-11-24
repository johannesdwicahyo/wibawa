module Wibawa
  # The Cmd+K dialog: every page the sidebar offers, "New ..." shortcuts, and
  # record search (filled in by wibawa.js from SearchController).
  #
  # Inherits from the sidebar only to reuse its list of visible resources and reports.
  class CommandPaletteComponent < SidebarComponent
    Item = Struct.new(:label, :url, :icon, :hint)

    def items
      resources = groups.flat_map(&:last)
      [Item.new(t("wibawa.dashboard"), root_path, "home", nil)] +
        resources.map { |r| Item.new(r.label, resources_path(resource: r.key), r.menu_icon, nil) } +
        report_groups.values.flatten.map { |r| Item.new(r.title, helpers.report_path(report: r.key), r.menu_icon, t("wibawa.reports")) } +
        resources.select { |r| r.action?(:new) && wibawa_authorized?(:new, r.model) }.map do |r|
          Item.new(t("wibawa.new_record", resource: r.singular_label), new_resource_path(resource: r.key), "plus", nil)
        end
    end
  end
end
