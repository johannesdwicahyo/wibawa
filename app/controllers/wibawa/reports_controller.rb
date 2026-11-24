require "csv"

module Wibawa
  class ReportsController < ApplicationController
    def show
      @report = Wibawa.registry.report(params[:report]) || raise(Wibawa::ResourceNotFound)
      wibawa_authorize!(:show, @report)
      @values = @report.values(params[:p])
      @rows = @report.run(@values)

      respond_to do |format|
        format.html
        format.csv { send_data csv(@rows), filename: "#{@report.key}-#{Time.now.strftime('%Y%m%d-%H%M')}.csv", type: "text/csv; charset=utf-8" }
      end
    end

    private

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
