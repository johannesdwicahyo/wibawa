module Wibawa
  # The "Views" popover on the index toolbar: the user's saved views and a
  # form that saves the current scope, search, filters and sort under a name.
  class SavedViewsComponent < BaseComponent
    def initialize(resource:)
      @resource = resource
    end

    attr_reader :resource

    def views
      @views ||= Wibawa::SavedView.visible_to(helpers.wibawa_current_user).where(resource_key: resource.key).order(:name).to_a
    end

    def current_query = @current_query ||= Wibawa::SavedView.normalize(request.query_parameters)
    def current = views.find { |view| view.query == current_query && current_query.present? }
    def url_for_view(view) = [ resources_path(resource: resource.key), view.query.presence ].compact.join("?")
    def create_url = helpers.saved_views_path(resource: resource.key)
    def destroy_url(view) = helpers.saved_view_path(resource: resource.key, id: view)
  end
end
