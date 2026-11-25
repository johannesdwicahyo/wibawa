module Wibawa
  # A read-only page built from a query: a table, an optional chart and CSV.
  #
  #   Wibawa.report :sales_by_status do
  #     title "Sales by status"
  #     param :from, as: :date, default: -> { 30.days.ago.to_date }
  #
  #     sql <<~SQL
  #       SELECT status, COUNT(*) AS orders, SUM(total) AS revenue
  #       FROM orders WHERE created_at >= :from GROUP BY status
  #     SQL
  #
  #     column :status
  #     column :orders
  #     column :revenue, as: :money
  #     chart x: :status, y: :revenue
  #   end
  #
  # `sql "...", on: WarehouseRecord` runs on that class's database, so a
  # warehouse is just another entry in database.yml. Instead of SQL you can
  # give a block: `query { |params| Order.where(...).group(:status).count }`.
  #
  # ponytail: the whole result is loaded, and the page shows the first
  # MAX_ROWS rows. Reports are meant for aggregates; page a raw table through a
  # resource instead.
  class Report
    MAX_ROWS = 1000
    MAX_SERIES = 6 # the validated colours in wibawa.css (--wb-series-1..6)

    Param = Struct.new(:name, :options) do
      def as = (options[:as] || :string).to_sym
      def label = options[:label] || Util.humanize(name)
      def collection = options[:collection]

      def default
        value = options[:default]
        value.respond_to?(:call) ? value.call : value
      end

      # Turns the submitted string into a Date, a number or a string; blank or
      # unparsable input falls back to the default.
      def cast(raw)
        value = raw.to_s.strip
        return default if value.empty?

        case as
        when :date then Date.iso8601(value)
        when :number then value.match?(/\A-?\d+\z/) ? value.to_i : Float(value)
        else value
        end
      rescue ArgumentError
        default
      end
    end

    attr_reader :key, :params, :chart_options

    def initialize(name, &block)
      @key = name.to_s
      @params = []
      @table = TableBuilder.new
      @menu = {}
      instance_eval(&block) if block
      raise Error, "Report #{@key.inspect} needs `sql` or `query`" unless @sql || @query
    end

    # ---- DSL ---------------------------------------------------------------

    def title(value = nil)
      value ? @title = value : (@title || Util.humanize(key))
    end

    def description(value = nil)
      value ? @description = value : @description
    end

    #   menu group: "Finance", icon: "receipt"
    def menu(**options)
      @menu = options
    end

    #   param :from, as: :date, default: -> { Date.current.beginning_of_month }
    #   param :status, as: :select, collection: %w[pending paid]
    def param(name, as: :string, default: nil, label: nil, collection: nil)
      @params << Param.new(name.to_sym, { as: as, default: default, label: label, collection: collection }.compact)
    end

    # SQL with :named placeholders, one per param. Values are bound, never interpolated.
    def sql(text, on: nil)
      @sql = text
      @on = on
    end

    # A block that gets the param values and returns a relation, a grouped
    # count/sum hash, or an array of hashes.
    def query(&block)
      @query = block
    end

    # Same options as an index column. Without any, every result column is shown.
    def column(name, **options)
      @table.column(name, **options)
    end

    #   chart x: :status, y: :revenue          # bars: compare categories
    #   chart :line, x: :month, y: :revenue    # a line: change over time, rows in time order
    #   chart :line, x: :month, y: %i[revenue refunds]   # several series on one axis, so one unit
    def chart(type = :bar, x:, y:)
      raise Error, "Unknown chart type #{type.inspect} (use :bar or :line)" unless %i[bar line].include?(type.to_sym)

      series = Array(y).map(&:to_s)
      raise Error, "A chart takes 1 to #{MAX_SERIES} series, got #{series.size}" unless (1..MAX_SERIES).cover?(series.size)

      @chart_options = { type: type.to_sym, x: x.to_s, y: series }
    end

    # ---- Reading and running -----------------------------------------------

    def menu_group = @menu[:group]
    def menu_icon = @menu[:icon] || "chart"

    # { from: Date, status: "paid" } from the submitted strings.
    def values(raw)
      raw = raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
      raw = (raw || {}).to_h.transform_keys(&:to_s)
      params.to_h { |param| [param.name, param.cast(raw[param.name.to_s])] }
    end

    # The result as an array of string-keyed hashes.
    def run(values)
      rows_from(@sql ? run_sql(values) : @query.call(values))
    end

    def columns(rows)
      return @table.columns unless @table.columns.empty?

      (rows.first&.keys || []).map { |name| Column.new(name.to_sym, {}, nil) }
    end

    private

    def run_sql(values)
      statement = ActiveRecord::Base.sanitize_sql_array([@sql, values])
      (@on || ActiveRecord::Base).with_connection { |connection| connection.select_all(statement) }
    end

    def rows_from(result)
      case result
      when ActiveRecord::Relation then result.klass.with_connection { |connection| connection.select_all(result.to_sql) }.to_a
      when ActiveRecord::Result then result.to_a
      when Hash then hash_rows(result)
      else Array(result).map { |row| (row.respond_to?(:attributes) ? row.attributes : row.to_h).transform_keys(&:to_s) }
      end
    end

    # `Order.group(:status).count` => { "paid" => 3 }: one row per key.
    def hash_rows(hash)
      names = @table.columns.map { |column| column.name.to_s }
      x = names[0] || @chart_options&.fetch(:x) || "name"
      y = names[1] || @chart_options&.fetch(:y)&.first || "value"
      hash.map { |group, value| { x => Array(group).join(" / "), y => value } }
    end
  end
end
