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
        format.csv { stream_csv_lines("#{@report.key}-#{Time.now.strftime('%Y%m%d-%H%M')}.csv", csv_lines(result)) }
      end
    end

    private

    def per_page
      requested = params[:per_page].to_i
      requested.positive? ? [ requested, Wibawa.config.max_per_page ].min : Wibawa.config.per_page
    end

    # CSV lines, fetched one batch at a time so a large export is never held in
    # memory. The first batch is read here, before the download starts, so a
    # query that fails shows the error page and not a broken file.
    # ponytail: batches use OFFSET, which slows down deep into a huge result;
    # page by a key column if exports reach millions of rows.
    def csv_lines(result)
      size = Wibawa::CsvExporter::BATCH_SIZE
      batch = result.rows(limit: size)
      columns = @report.columns(batch)

      Enumerator.new do |out|
        out << "﻿" # BOM so Excel opens UTF-8 correctly
        out << CSV.generate_line(columns.map(&:label))
        offset = 0
        loop do
          batch.each { |row| out << CSV.generate_line(columns.map { |column| safe(row[column.name.to_s]) }) }
          break if batch.size < size

          batch = result.rows(limit: size, offset: offset += size)
        end
      end
    end

    # Neutralize spreadsheet formulas (CSV injection), as the resource export does.
    def safe(value)
      text = value.to_s
      text.match?(Wibawa::CsvExporter::FORMULA_PREFIX) ? "'#{text}" : text
    end
  end
end
