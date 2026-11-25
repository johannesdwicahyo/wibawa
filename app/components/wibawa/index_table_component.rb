module Wibawa
  # The index table: one component for the whole table. Cells are formatted
  # with plain presenter methods, never one component per cell, so large pages
  # stay fast.
  class IndexTableComponent < BaseComponent
    BATCH_FORM_ID = "wb-batch-form".freeze
    NUMERIC_AS = %i[money number percentage].freeze
    NUMERIC_TYPES = %i[integer bigint decimal float].freeze

    def initialize(resource:, records:, query:)
      @resource = resource
      @records = records
      @query = query
    end

    attr_reader :resource, :records, :query

    def columns = @columns ||= resource.index_columns
    def model = resource.model
    def batch_form_id = BATCH_FORM_ID

    def selectable?
      return @selectable if defined?(@selectable)

      @selectable = resource.selectable? && batch_actions.any?
    end

    def batch_actions
      @batch_actions ||= resource.batch_actions.select { |a| wibawa_authorized?(:"batch_#{a.name}", model) }
    end

    def batch_confirm(action)
      return nil unless action.confirm

      action.confirm == true ? t("wibawa.confirm_batch", action: action.label.downcase) : action.confirm
    end

    def numeric?(column)
      return NUMERIC_AS.include?(column.as.to_sym) if column.as
      return false if column.name == :id || column.block || model.defined_enums.key?(column.name.to_s) # enums are integers in the DB, words on screen

      NUMERIC_TYPES.include?(model.columns_hash[column.name.to_s]&.type) && model.reflect_on_association(column.name).nil?
    end

    # Row height: 40 px, or 32 px with `index density: :compact`.
    def row_pad = resource.index_options[:density].to_s == "compact" ? "h-8 py-0.5" : "h-10 py-1.5"

    # The header stays put while the table scrolls inside its card. Its bottom
    # line is a shadow: a border on a sticky cell scrolls away with the rows.
    def th_class(*extra) = class_names("bg-surface-2 shadow-[inset_0_-1px_0_var(--color-line)]", *extra)

    # On phones the first column stays in view while the others scroll sideways.
    def pinned(column, surface)
      return unless column.equal?(columns.first)

      class_names("max-sm:sticky max-sm:left-0 max-sm:max-w-40 max-sm:overflow-hidden max-sm:text-ellipsis max-sm:whitespace-nowrap",
                surface == :header ? "max-sm:bg-surface-2" : "max-sm:bg-surface max-sm:shadow-[inset_-1px_0_0_var(--color-line)]")
    end

    def sortable?(column) = column.sort_expression(model).present?
    def sorted?(column) = query.sort_key == column.name.to_s

    def sort_url(column)
      direction = sorted?(column) && query.sort_direction == :desc ? "asc" : "desc"
      resources_path(resource: resource.key, **preserved_params("page", "sort", "direction").symbolize_keys,
                     sort: column.name, direction: direction)
    end

    def sort_icon(column)
      return "sort" unless sorted?(column)

      query.sort_direction == :asc ? "chevron-up" : "chevron-down"
    end

    def aria_sort(column)
      return nil unless sorted?(column)

      query.sort_direction == :asc ? "ascending" : "descending"
    end

    # ---- row actions ------------------------------------------------------

    def row_actions_config = resource.row_actions

    def show_row_action?(name)
      only = row_actions_config[:only]
      (only.nil? || only.include?(name)) && resource.action?(name)
    end

    def row_actions?
      %i[show edit destroy].any? { |a| show_row_action?(a) } || row_actions_config[:block]
    end

    def custom_row_actions(record)
      block = row_actions_config[:block]
      block ? helpers.instance_exec(record, &block) : nil
    end

    def cell(record, column)
      html = presenter.cell(record, column)
      return html if column.link? || column.block || !first_link_column?(column) || model.reflect_on_association(column.name)

      presenter.link_to_record(record, html)
    end

    def empty_message
      query.filtered? ? t("wibawa.empty_filtered", resource: resource.label.to_s.downcase) : t("wibawa.empty", resource: resource.label.to_s.downcase)
    end

    def can_create?
      resource.action?(:new) && wibawa_authorized?(:new, model)
    end

    private

    # When no column has `link: true`, the first column links to the record.
    def first_link_column?(column)
      @first_link_column ||= columns.any?(&:link?) ? :none : columns.first
      @first_link_column.equal?(column)
    end
  end
end
