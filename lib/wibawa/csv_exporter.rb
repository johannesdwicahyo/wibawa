require "csv"

module Wibawa
  # Streams a resource's filtered relation as CSV, one batch at a time, in the
  # order the index page shows. No batch uses OFFSET, so the last batch of a
  # large export costs the same as the first.
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
      return @relation.find_each(batch_size: BATCH_SIZE, &block) if @relation.order_values.empty?

      key = @relation.klass.primary_key
      ids = sorted_ids(key) if key.is_a?(String)
      return each_by_offset(&block) unless ids

      # Records are fetched by id, a batch at a time, and put back in the sorted order.
      scope = @relation.unscope(:order, :limit, :offset)
      ids.each_slice(BATCH_SIZE) do |slice|
        records = scope.where(key => slice).index_by { |record| record.public_send(key) }
        slice.each { |id| (record = records[id]) && block.call(record) } # a record deleted meanwhile is skipped
      end
    end

    # Every id in the sorted order, from one query.
    # ponytail: all ids are held in memory (about 8 MB per million rows); move
    # to a keyset cursor on the sort column if exports outgrow that.
    def sorted_ids(key)
      @relation.pluck(@relation.klass.arel_table[key])
    rescue ActiveRecord::StatementInvalid
      nil # e.g. SELECT DISTINCT with an ORDER BY the database will not accept here
    end

    # For models without a single primary key.
    def each_by_offset(&block)
      offset = 0
      loop do
        batch = @relation.limit(BATCH_SIZE).offset(offset).to_a
        break if batch.empty?

        batch.each(&block)
        offset += BATCH_SIZE
      end
    end

    # Neutralize spreadsheet formulas (CSV injection).
    def safe(value)
      str = value.to_s
      str.match?(FORMULA_PREFIX) ? "'#{str}" : str
    end
  end
end
