module Wibawa
  class ReportPageComponent < BaseComponent
    CHART_BARS = 30

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
      return [] unless (chart = report.chart_options)

      points = rows.first(CHART_BARS).map { |row| [row[chart[:x]].to_s, row[chart[:y]].to_f, row[chart[:y]]] }
      max = points.map { |_, number, _| number }.max.to_f
      points.map { |label, number, raw| [label, raw, max.positive? ? (number.clamp(0, max) / max * 100).round(2) : 0] }
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
