require "csv"

module Wibawa
  # Streams a resource's filtered relation as CSV, one batch at a time.
  class CsvExporter
    BATCH_SIZE = 1000
    FORMULA_PREFIX = /\A[=+\-@\t\r]/

    def initialize(resource, relation, presenter)
      @resource = resource
      @relation = relation
      @presenter = presenter
      @columns = resource.csv_columns
    end

    def filename
      "#{@resource.key}-#{Time.now.strftime('%Y%m%d-%H%M')}.csv"
    end

    # An Enumerator of CSV lines, suitable for `response_body`.
    def lines
      Enumerator.new do |out|
        out << "﻿" # BOM so Excel opens UTF-8 correctly
        out << CSV.generate_line(@columns.map(&:label))
        each_record do |record|
          out << CSV.generate_line(@columns.map { |c| safe(@presenter.plain(record, c)) })
        end
      end
    end

    private

    def each_record(&block)
      if @relation.order_values.empty?
        @relation.find_each(batch_size: BATCH_SIZE, &block)
      else
        offset = 0
        loop do
          batch = @relation.limit(BATCH_SIZE).offset(offset).to_a
          break if batch.empty?

          batch.each(&block)
          offset += BATCH_SIZE
        end
      end
    end

    # Neutralize spreadsheet formulas (CSV injection).
    def safe(value)
      str = value.to_s
      str.match?(FORMULA_PREFIX) ? "'#{str}" : str
    end
  end
end
