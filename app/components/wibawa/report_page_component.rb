module Wibawa
  class ReportPageComponent < BaseComponent
    CHART_BARS = 30
    CHART_POINTS = 366
    X_LABELS = 6

    Series = Struct.new(:column, :color) do
      def name = column.name.to_s
      def label = column.label
    end
    # One x position of the line chart: its label, how far from the left (%),
    # and per series [series, raw value, height from the bottom (%)].
    Point = Struct.new(:label, :x, :marks)

    FORM_ID = "wb-report-form"

    # `page` holds the table's rows; `chart_rows` is the start of the result.
    def initialize(report:, values:, page:, chart_rows: [])
      @report = report
      @values = values
      @page = page
      @chart_rows = chart_rows
    end

    attr_reader :report, :values, :page, :chart_rows

    def rows = page.records
    def columns = @columns ||= report.columns(rows.presence || chart_rows)
    def empty? = rows.empty? && !page.prev?

    def header_actions
      [ { label: t("wibawa.export_csv"), icon: "download", style: :secondary, data: { turbo: false },
         url: helpers.report_path(report: report.key, format: :csv, p: request.query_parameters["p"]) } ]
    end

    def cell(row, column)
      value = row[column.name.to_s]
      column.block ? helpers.instance_exec(row, &column.block) : presenter.format(value, column.as, column: column)
    end

    def numeric?(column)
      %i[money number percentage].include?(column.as&.to_sym) || (column.as.nil? && rows.first&.fetch(column.name.to_s, nil).is_a?(Numeric))
    end

    # The charted columns. One series wears the brand colour; several take the
    # fixed colour order, so a series keeps its colour whatever the data.
    def series
      @series ||= begin
        names = Array(report.chart_options&.fetch(:y))
        names.each_with_index.map do |name, index|
          Series.new(columns.find { |column| column.name.to_s == name } || Column.new(name.to_sym, {}, nil),
                     names.one? ? "var(--wb-primary-effective)" : "var(--wb-series-#{index + 1})")
        end
      end
    end

    def chart_type = report.chart_options&.fetch(:type)
    def chart_label = series.map(&:label).to_sentence

    # [[label, [[series, raw value, percent of the largest], ...]], ...] for the
    # bar chart. Every series shares one scale.
    # ponytail: bars start at zero, so negative values draw as empty bars.
    def bars
      return [] unless chart_type == :bar

      shown = chart_rows.first(CHART_BARS)
      max = shown.flat_map { |row| series.map { |one| row[one.name].to_f } }.max.to_f
      shown.map do |row|
        [ row[report.chart_options[:x]].to_s.presence || "—",
         series.map { |one| [ one, row[one.name], max.positive? ? (row[one.name].to_f.clamp(0, max) / max * 100).round(2) : 0 ] } ]
      end
    end

    # Every point sits in the middle of its own equal-width column, which is
    # also its hover target.
    # ponytail: a missing value draws as zero; break the line there if reports with gaps turn up.
    def line_points
      @line_points ||= begin
        low, high = y_range
        line_rows.each_with_index.map do |row, index|
          Point.new(row[report.chart_options[:x]].to_s, ((index + 0.5) / line_rows.size * 100).round(2),
                    series.map { |one| [ one, row[one.name], high == low ? 50.0 : ((row[one.name].to_f - low) / (high - low) * 100).round(2) ] })
        end
      end
    end

    def line_rows = chart_type == :line ? chart_rows.first(CHART_POINTS) : []

    # One value axis for every series. It always includes zero, so the height of a line means something.
    def y_range
      values = line_rows.flat_map { |row| series.map { |one| row[one.name].to_f } }
      [ [ *values, 0 ].min, [ *values, 0 ].max ]
    end

    # Top, middle and bottom of the value axis.
    def y_ticks
      low, high = y_range
      [ high, (high + low) / 2.0, low ]
    end

    def polyline(index) = line_points.map { |point| "#{point.x},#{(100 - point.marks[index][2]).round(2)}" }.join(" ")

    # A handful of evenly spaced labels for the time axis.
    def x_labels
      count = [ line_points.size, X_LABELS ].min
      Array.new(count) { |i| line_points[count == 1 ? 0 : (i * (line_points.size - 1) / (count - 1.0)).round].label }
    end

    # Values on the shared axis are written the way the first series is.
    def chart_value(raw, one = series.first) = presenter.format(raw, one.column.as, column: one.column)
    def chart_text(raw, one = series.first) = helpers.strip_tags(chart_value(raw, one).to_s)

    def param_name(param) = "p[#{param.name}]"
    def param_id(param) = "wb-report-#{param.name}"

    def options_for(param)
      Array(param.collection).map { |item| item.is_a?(Array) ? item : [ Util.humanize(item.to_s), item ] }
    end
  end
end
