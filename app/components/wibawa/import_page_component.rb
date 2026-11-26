module Wibawa
  # The CSV import page: the result of the last upload, the upload form, the
  # columns a file may use, and the user's recent background imports.
  class ImportPageComponent < BaseComponent
    # importer: a Wibawa::CsvImporter; result: its Result after an upload, or nil; recent: Wibawa::Import records
    def initialize(resource:, importer:, result: nil, recent: nil)
      @resource = resource
      @importer = importer
      @result = result
      @recent = recent
    end

    attr_reader :resource, :importer, :result

    def title = t("wibawa.import.title", resource: resource.label)
    def breadcrumbs = [ [ resource.label, resources_path(resource: resource.key) ], [ t("wibawa.import.button"), nil ] ]
    def form_url = import_resource_path(resource: resource.key)
    def template_url = import_resource_path(resource: resource.key, format: :csv)
    def cancel_url = resources_path(resource: resource.key)

    # The names shown under "Columns you can use".
    def columns = importer.attributes
    def key_label = importer.key && resource.model.human_attribute_name(importer.key)

    def background? = Wibawa::Import.possible?(resource, helpers.wibawa_current_user)
    def row_limit = background? ? Wibawa::Import::MAX_ROWS : Wibawa::CsvImporter::MAX_ROWS
    def recent = @recent.to_a
    def import_label(import) = import.filename.presence || "##{import.id}"
    def import_url(import) = import_status_resource_path(resource: resource.key, id: import)
  end
end
