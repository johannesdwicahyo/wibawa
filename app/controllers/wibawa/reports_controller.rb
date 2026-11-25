require "csv"

module Wibawa
  class ReportsController < ApplicationController
    def show
      @report = Wibawa.registry.report(params[:report]) || raise(Wibawa::ResourceNotFound)
      wibawa_authorize!(:show, @report)
      @values = @report.values(params[:p])
      result = @report.result(@values)

      respond_to do |format|
        format.html do
          @page = Wibawa::ReportPaginator.new(result, page: params[:page], per_page: per_page)
          # The chart draws the start of the result, whichever page the table is on.
          @chart_rows = @report.chart_options ? result.rows(limit: Wibawa::ReportPageComponent::CHART_POINTS) : []
        end
        # ponytail: the CSV is built in memory from the whole result; stream it if exports get large.
        format.csv { send_data csv(result.all), filename: "#{@report.key}-#{Time.now.strftime('%Y%m%d-%H%M')}.csv", type: "text/csv; charset=utf-8" }
      end
    end

    private

    def per_page
      requested = params[:per_page].to_i
      requested.positive? ? [requested, Wibawa.config.max_per_page].min : Wibawa.config.per_page
    end

    def csv(rows)
      columns = @report.columns(rows)
      body = CSV.generate do |out|
        out << columns.map(&:label)
        rows.each { |row| out << columns.map { |column| safe(row[column.name.to_s]) } }
      end
      "﻿#{body}" # BOM so Excel opens UTF-8 correctly
    end

    # Neutralize spreadsheet formulas (CSV injection), as the resource export does.
    def safe(value)
      text = value.to_s
      text.match?(Wibawa::CsvExporter::FORMULA_PREFIX) ? "'#{text}" : text
    end
  end
end
