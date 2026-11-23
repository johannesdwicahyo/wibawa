module Wibawa
  # Evaluates `Wibawa.dashboard do ... end`.
  #
  #   Wibawa.dashboard do
  #     stat("Orders today", as: :number) { Order.where(created_at: Date.current.all_day).count }
  #     stat("Revenue today", as: :money) { Order.paid.where(created_at: Date.current.all_day).sum(:total) }
  #
  #     table "Latest orders", resource: :orders do
  #       Order.order(created_at: :desc).limit(10)
  #     end
  #   end
  class Dashboard
    Stat = Struct.new(:label, :options, :block)
    Table = Struct.new(:title, :options, :block, :builder)

    attr_reader :stats, :tables

    def initialize(&block)
      @stats = []
      @tables = []
      instance_eval(&block) if block
    end

    def stat(label, as: nil, hint: nil, link: nil, &block)
      @stats << Stat.new(label, { as: as, hint: hint, link: link }.compact, block)
    end

    # `resource:` links rows to that resource and reuses its index columns
    # unless you pass `columns:` or a column block via `with:`.
    def table(title, resource: nil, columns: nil, with: nil, &relation)
      builder = nil
      if with
        builder = TableBuilder.new
        builder.instance_eval(&with)
      elsif columns
        builder = TableBuilder.new
        columns.each { |c| builder.column(c) }
      end
      @tables << Table.new(title, { resource: resource&.to_s }.compact, relation, builder)
    end
  end
end
