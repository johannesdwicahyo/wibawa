module Wibawa
  class IndexPageComponent < BaseComponent
    FORM_ID = "wb-index-form".freeze

    def initialize(resource:, query:, page:)
      @resource = resource
      @query = query
      @page = page
    end

    attr_reader :resource, :query, :page

    def header_actions
      list = []
      if resource.action?(:index) && wibawa_authorized?(:export, resource.model)
        list << { label: t("wibawa.export_csv"), icon: "download", style: :secondary,
                  url: resources_path(resource: resource.key, format: :csv, **preserved_params("page", "per_page").symbolize_keys),
                  data: { turbo: false } }
      end
      if resource.importable? && wibawa_authorized?(:import, resource.model)
        list << { label: t("wibawa.import.button"), icon: "file", style: :secondary, url: import_resource_path(resource: resource.key) }
      end
      if resource.action?(:new) && wibawa_authorized?(:new, resource.model)
        list << { label: t("wibawa.new_record", resource: resource.singular_label), icon: "plus", style: :primary,
                  url: new_resource_path(resource: resource.key) }
      end
      list
    end

    def search? = resource.search_fields.present?
    def filters? = resource.filters.any?
    def saved_views? = !!Wibawa.config.saved_views
    def form_id = FORM_ID

    def clear_url
      params = {}
      params[:scope] = query.params[:scope] if query.params[:scope].present?
      resources_path(resource: resource.key, **params)
    end
  end
end
