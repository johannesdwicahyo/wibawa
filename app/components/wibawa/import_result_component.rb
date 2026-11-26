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

    def preview_headings = [ t("wibawa.import.row"), t("wibawa.import.action"), t("wibawa.audit.record"), t("wibawa.audit.changes") ]

    # One preview row as the table's four cells.
    def preview_cells(line, action, label, changes)
      [ content_tag(:span, line, class: "tabular-nums text-ink-2"), content_tag(:span, t("wibawa.import.#{action}"), class: "whitespace-nowrap"),
        label, changes_html(changes) ]
    end

    def changes_html(changes)
      return content_tag(:span, t("wibawa.import.no_change"), class: "text-ink-2") if changes.empty?

      safe_join(changes.map do |name, value|
        content_tag(:div, safe_join([ content_tag(:span, "#{attribute_label(name)}:", class: "text-ink-2"), " ", change(value) ]), class: "break-words")
      end)
    end
  end
end
