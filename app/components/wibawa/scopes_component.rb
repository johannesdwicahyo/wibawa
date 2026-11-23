module Wibawa
  class ScopesComponent < BaseComponent
    def initialize(resource:, query:)
      @resource = resource
      @query = query
    end

    attr_reader :resource, :query

    def scopes = resource.scopes
    def current?(scope) = query.current_scope&.name == scope.name

    def url_for_scope(scope)
      resources_path(resource: resource.key, **preserved_params("page", "scope").symbolize_keys, scope: scope.name)
    end

    def count_for(scope)
      return nil unless Wibawa.config.scope_counts && scope.options[:count] != false

      presenter.view.number_with_delimiter(query.scope_count(scope))
    end
  end
end
