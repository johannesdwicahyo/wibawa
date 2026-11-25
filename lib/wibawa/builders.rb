module Wibawa
  # Evaluates `index do ... end`, `csv do ... end` and table_for blocks.
  class TableBuilder
    attr_reader :columns, :row_actions

    def initialize
      @columns = []
      @row_actions = nil
      @selectable = nil
    end

    #   column :total, as: :money
    #   column :customer, sortable: "customers.name"
    #   column("Items") { |order| order.line_items.size }
    def column(name, as: nil, label: nil, sortable: nil, link: nil, **options, &block)
      if name.is_a?(String) && label.nil?
        label = name
        name = Util.underscore(name.tr(" ", "_")).to_sym
        sortable = false if sortable.nil?
      end
      opts = { as: as, label: label, sortable: sortable, link: link }.merge(options).compact
      @columns << Column.new(name.to_sym, opts, block)
    end

    def id_column
      column :id, link: true
    end

    # Adds the View / Edit / Delete links. Pass a block for extra links:
    #   actions { |order| link_to "Invoice", invoice_path(order) }
    def actions(only: nil, &block)
      @row_actions = { only: only && Array(only).map(&:to_sym), block: block }
    end

    def selectable(value = true)
      @selectable = value
    end

    def selectable?
      @selectable
    end
  end

  class IndexBuilder < TableBuilder
    attr_reader :options

    def initialize(**options)
      super()
      @options = options
    end
  end

  # Evaluates `show do ... end`.
  class ShowBuilder
    attr_reader :items

    def initialize
      @items = []
    end

    def row(name, as: nil, label: nil, **options, &block)
      @items << [ :row, Column.new(name.to_sym, { as: as, label: label }.merge(options).compact, block) ]
    end

    # Rows that hold several attributes at once:
    #   attributes :name, :email, :created_at
    def attributes(*names)
      names.each { |n| row(n) }
    end

    # A titled box whose content comes from the block (run in the view, gets the record).
    #   panel("Notes") { |order| simple_format(order.notes) }
    def panel(title, &block)
      @items << [ :panel, title, block ]
    end

    # A table of associated records:
    #   table_for :line_items do
    #     column :product
    #     column :quantity
    #   end
    def table_for(association, title: nil, limit: 25, &block)
      table = TableBuilder.new
      table.instance_eval(&block) if block
      @items << [ :table, association.to_sym, { title: title, limit: limit }, table ]
    end
  end

  # Evaluates `form do ... end`.
  class FormBuilder
    attr_reader :items

    def initialize
      @items = []
    end

    #   field :status, as: :select, collection: Order.statuses.keys
    #   field :notes, as: :text, hint: "Visible to staff only"
    def field(name, as: nil, label: nil, hint: nil, collection: nil, **options)
      opts = { as: as, label: label, hint: hint, collection: collection }.merge(options).compact
      @items << Field.new(:field, name.to_sym, opts, [])
    end

    def fields(*names)
      names.each { |n| field(n) }
    end

    # Nested records via accepts_nested_attributes_for.
    #   has_many :line_items, sortable: :position do
    #     field :product
    #     field :quantity
    #   end
    def has_many(association, sortable: nil, allow_destroy: true, label: nil, &block)
      sub = FormBuilder.new
      sub.instance_eval(&block) if block
      sortable = :position if sortable == true
      opts = { sortable: sortable, allow_destroy: allow_destroy, label: label }.compact
      @items << Field.new(:has_many, association.to_sym, opts, sub.items)
    end

    # Groups fields under a heading.
    def section(title, &block)
      sub = FormBuilder.new
      sub.instance_eval(&block) if block
      @items << Field.new(:section, title, {}, sub.items)
    end
  end
end
