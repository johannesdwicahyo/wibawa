module Wibawa
  class ReportPageComponent < BaseComponent
    CHART_BARS = 30
    CHART_POINTS = 366
    X_LABELS = 6

    Point = Struct.new(:label, :raw, :x, :y)

    def initialize(report:, values:, rows:)
      @report = report
      @values = values
      @rows = rows
    end

    attr_reader :report, :values, :rows

    def columns = @columns ||= report.columns(rows)
    def shown_rows = rows.first(Wibawa::Report::MAX_ROWS)
    def truncated? = rows.size > Wibawa::Report::MAX_ROWS

    def header_actions
      [{ label: t("wibawa.export_csv"), icon: "download", style: :secondary, data: { turbo: false },
         url: helpers.report_path(report: report.key, format: :csv, p: request.query_parameters["p"]) }]
    end

    def cell(row, column)
      value = row[column.name.to_s]
      column.block ? helpers.instance_exec(row, &column.block) : presenter.format(value, column.as, column: column)
    end

    def numeric?(column)
      %i[money number percentage].include?(column.as&.to_sym) || (column.as.nil? && rows.first&.fetch(column.name.to_s, nil).is_a?(Numeric))
    end

    # [[label, value, percent of the largest], ...] for the bar chart.
    # ponytail: bars start at zero, so negative values draw as empty bars.
    def bars
      return [] unless (chart = report.chart_options) && chart[:type] == :bar

      points = rows.first(CHART_BARS).map { |row| [row[chart[:x]].to_s, row[chart[:y]].to_f, row[chart[:y]]] }
      max = points.map { |_, number, _| number }.max.to_f
      points.map { |label, number, raw| [label, raw, max.positive? ? (number.clamp(0, max) / max * 100).round(2) : 0] }
    end

    # Points of the line chart, each with its place in the plot as percentages:
    # x from the left, y from the bottom. Every point sits in the middle of its
    # own equal-width column, which is also its hover target.
    def line_points
      @line_points ||= begin
        chart = report.chart_options
        rows = chart && chart[:type] == :line ? self.rows.first(CHART_POINTS) : []
        low, high = y_range(rows.map { |row| row[chart[:y]].to_f }) if rows.any?
        rows.each_with_index.map do |row, index|
          value = row[chart[:y]].to_f
          Point.new(row[chart[:x]].to_s, row[chart[:y]], ((index + 0.5) / rows.size * 100).round(2),
                    high == low ? 50.0 : ((value - low) / (high - low) * 100).round(2))
        end
      end
    end

    # The value axis always includes zero, so the height of the line means something.
    def y_range(values) = [[values.min, 0].min, [values.max, 0].max]

    # Top, middle and bottom of the value axis.
    def y_ticks
      low, high = y_range(line_points.map { |point| point.raw.to_f })
      [high, (high + low) / 2.0, low]
    end

    def polyline = line_points.map { |point| "#{point.x},#{(100 - point.y).round(2)}" }.join(" ")

    # A handful of evenly spaced labels for the time axis.
    def x_labels
      count = [line_points.size, X_LABELS].min
      Array.new(count) { |i| line_points[count == 1 ? 0 : (i * (line_points.size - 1) / (count - 1.0)).round].label }
    end

    def chart_column = columns.find { |column| column.name.to_s == report.chart_options[:y] } || Column.new(report.chart_options[:y].to_sym, {}, nil)
    def chart_value(raw) = presenter.format(raw, chart_column.as, column: chart_column)

    def param_name(param) = "p[#{param.name}]"
    def param_id(param) = "wb-report-#{param.name}"

    def options_for(param)
      Array(param.collection).map { |item| item.is_a?(Array) ? item : [Util.humanize(item.to_s), item] }
    end
  end
end
