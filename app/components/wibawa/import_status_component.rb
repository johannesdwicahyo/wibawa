module Wibawa
  # Where a background import is watched: waiting (wibawa.js loads the page
  # again every few seconds while [data-wb-reload] is on it), then what it did.
  class ImportStatusComponent < BaseComponent
    # import: a Wibawa::Import
    def initialize(resource:, import:)
      @resource = resource
      @import = import
    end

    attr_reader :resource, :import

    def title = t("wibawa.import.title", resource: resource.label)
    def label = import.filename.presence || "##{import.id}"
    def breadcrumbs
      [ [ resource.label, resources_path(resource: resource.key) ], [ t("wibawa.import.button"), import_resource_path(resource: resource.key) ], [ label, nil ] ]
    end

    def waiting? = import.waiting?
    def status_text = t("wibawa.import.status.#{import.status}")
    def outcome = @outcome ||= import.outcome
    # A real import that went through; everything else (errors, a check) is drawn by import_result.
    def imported? = outcome.ok? && !import.dry_run
    def status_url = import_status_resource_path(resource: resource.key, id: import)
    def import_url = import_resource_path(resource: resource.key)
    def index_url = resources_path(resource: resource.key)
  end
end
