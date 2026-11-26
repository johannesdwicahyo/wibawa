module Wibawa
  # The "Views" popover on the index toolbar: the user's saved views, the ones shared with them, and a
  # form that saves the current scope, search, filters and sort under a name. Their own views open to rename, share, set as default or delete.
  class SavedViewsComponent < BaseComponent
    def initialize(resource:)
      @resource = resource
    end

    attr_reader :resource

    def views
      @views ||= Wibawa::SavedView.visible_to(helpers.wibawa_current_user).where(resource_key: resource.key).order(:name).to_a
    end

    def current_query = @current_query ||= Wibawa::SavedView.normalize(request.query_parameters, default_per_page: Wibawa::SavedView.default_per_page(resource))
    def current = views.find { |view| view.query == current_query && current_query.present? }
    def url_for_view(view) = [ resources_path(resource: resource.key), view.query.presence ].compact.join("?")
    def create_url = helpers.saved_views_path(resource: resource.key)
    def own?(view) = view.owned_by?(helpers.wibawa_current_user)
    # With no signed-in user every view is everyone's already.
    def sharing? = Wibawa::SavedView.owner_key(helpers.wibawa_current_user).present?
    def badge_class = "shrink-0 rounded-full bg-surface-2 px-1.5 py-0.5 text-xs font-medium text-ink-2"
    def check_class = "size-4 rounded border-line accent-[var(--color-primary)]"
    def update_url(view) = helpers.saved_view_path(resource: resource.key, id: view)
    def destroy_url(view) = helpers.saved_view_path(resource: resource.key, id: view)
  end
end
