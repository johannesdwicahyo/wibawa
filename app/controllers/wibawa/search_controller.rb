module Wibawa
  # Record search for the command palette: a few hits from every searchable
  # resource, as an HTML fragment the palette drops into its list.
  #
  # ponytail: one LIKE query per searchable resource per (debounced) keystroke.
  # Fine for dozens of resources; add a per-resource opt-out if it ever hurts.
  class SearchController < ApplicationController
    PER_RESOURCE = 5
    MIN_LENGTH = 2

    def index
      term = params[:q].to_s.strip
      @hits = term.length < MIN_LENGTH ? [] : Wibawa.registry.flat_map { |resource| hits_for(resource, term) }
      render layout: false
    end

    private

    # [[resource, record, path], ...]
    def hits_for(resource, term)
      return [] if resource.search_fields.blank? || !resource.action?(:index) || !wibawa_authorized?(:index, resource.model)

      query = Wibawa::Query.new(resource, collection_for(resource), { search: term })
      query.relation.limit(PER_RESOURCE).filter_map do |record|
        path = path_for(resource, record)
        [ resource, record, path ] if path
      end
    end

    # Each resource's `controller do` overrides are installed on the controller
    # instance, so every resource gets a fresh one rather than sharing this one.
    def collection_for(resource)
      scope = ResourcesController.new
      scope.set_request!(request)
      scope.set_response!(response)
      scope.send(:use_resource, resource.key)
      scope.send(:authorized_collection)
    end

    def path_for(resource, record)
      if resource.action?(:show) && wibawa_authorized?(:show, record)
        resource_path(resource: resource.key, id: record)
      elsif resource.action?(:edit) && wibawa_authorized?(:edit, record)
        edit_resource_path(resource: resource.key, id: record)
      end
    end
  end
end
