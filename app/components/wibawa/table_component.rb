module Wibawa
  # A plain table of rows: the associated records on a record's page, a
  # dashboard table, a report's rows, an import preview. (The index table,
  # with its sorting, selection and row actions, is IndexTableComponent.)
  #
  # It is given finished cells, never one component per cell, so a report
  # page of a thousand rows stays fast.
  class TableComponent < BaseComponent
    # headings: one label per column
    # rows:     anything enumerable
    # cells:    ->(row) { [cell, ...] }, one per heading, already formatted
    # numeric:  indexes of the columns to align right
    # style:    :inset (inside a card, under its title) or :full (a card of its own)
    # align:    :top for rows whose cells run to several lines
    def initialize(headings:, rows:, cells:, numeric: [], caption: nil, style: :inset, align: nil)
      @headings = headings
      @rows = rows
      @cells = cells
      @numeric = numeric
      @caption = caption
      @style = style
      @align = align
    end

    attr_reader :headings, :rows, :caption

    def full? = @style == :full
    def numeric?(index) = @numeric.include?(index)
    def cells_for(row) = @cells.call(row)

    def head_row_class
      class_names(caption ? "border-y" : "border-b", "border-line text-left", "bg-surface-2" => full?)
    end

    def heading_class(index)
      class_names("whitespace-nowrap font-medium text-ink-2", full? ? "px-4 py-2.5" : "px-5 py-2", "text-right" => numeric?(index))
    end

    def row_class
      class_names("transition-colors hover:bg-surface-2" => full?, "align-top" => @align == :top)
    end

    def cell_class(index)
      class_names("text-ink", full? ? "px-4 py-2 align-middle" : "px-5 py-2.5", "text-right tabular-nums" => numeric?(index))
    end

    # Worked out once per column, not once per cell.
    def cell_classes = @cell_classes ||= headings.each_index.map { |index| cell_class(index) }
  end
end
