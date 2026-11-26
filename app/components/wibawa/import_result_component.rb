module Wibawa
  # What an import did or would do: its errors by line, or after a dry run
  # the counts and the first rows with what would change in each.
  class ImportResultComponent < BaseComponent
    # result: a Wibawa::CsvImporter::Result
    def initialize(resource:, result:)
      @resource = resource
      @result = result
    end

    attr_reader :resource, :result

    def errors = result.errors
    def failed? = !result.ok?
    def checked? = result.ok? && result.dry_run
    # [[line, :create or :update, record label, { attribute => [old, new] }], ...]
    def preview = result.preview
    def attribute_label(name) = resource.model.human_attribute_name(name)
    def change(value) = helpers.wibawa_change(value)
  end
end
