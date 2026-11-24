require "csv"

module Wibawa
  # Creates (and, with a key, updates) records from an uploaded CSV. All rows
  # go in or none do: any invalid row rolls the whole file back and is reported
  # with its line number.
  #
  # ponytail: runs inside the request, so files are capped at MAX_ROWS. Move it
  # to a background job when someone needs more.
  class CsvImporter
    MAX_ROWS = 5000
    MAX_ERRORS = 20

    Result = Struct.new(:created, :updated, :errors) do
      def ok? = errors.empty?
    end

    # find_in: relation to look existing records up in; build: -> { new record };
    # authorize: ->(action, record) { true or false }
    def initialize(resource, find_in:, build:, authorize:)
      @resource = resource
      @find_in = find_in
      @build = build
      @authorize = authorize
    end

    def model = @resource.model
    def attributes = @resource.import_attributes
    def key = @resource.import_options[:key]

    # Header row for the template file.
    def headers = attributes.map(&:to_s)

    def call(text)
      result = Result.new(0, 0, [])
      table = CSV.parse(text.to_s.dup.force_encoding(Encoding::UTF_8).delete_prefix("﻿"), headers: true, skip_blanks: true)
      mapping = map_headers(table.headers.compact, result)
      result.errors << [nil, I18n.t("wibawa.import.too_many", count: MAX_ROWS)] if table.size > MAX_ROWS
      return result unless result.ok?

      model.transaction do
        table.each.with_index(2) do |row, line|
          import_row(row, mapping, line, result)
          break if result.errors.size >= MAX_ERRORS
        end
        raise ActiveRecord::Rollback unless result.ok?
      end
      result.created = result.updated = 0 unless result.ok?
      result
    rescue CSV::MalformedCSVError => e
      Result.new(0, 0, [[e.line_number, e.message]])
    end

    private

    # { "Customer" => :customer_id }: a header may be the attribute name or its
    # human label, in any case. Unknown headers stop the import.
    def map_headers(headers, result)
      known = attributes.flat_map { |attribute| [[normalize(attribute), attribute], [normalize(model.human_attribute_name(attribute)), attribute]] }.to_h
      mapping = headers.to_h { |header| [header, known[normalize(header)]] }
      unknown = mapping.select { |_, attribute| attribute.nil? }.keys
      result.errors << [1, I18n.t("wibawa.import.unknown_columns", columns: unknown.join(", "))] if unknown.any?
      mapping
    end

    def normalize(text) = text.to_s.strip.downcase.gsub(/[\s_]+/, "_")

    def import_row(row, mapping, line, result)
      # Blank cells are left out: a new record keeps its defaults and an
      # existing one keeps its value. An import never wipes data.
      values = mapping.to_h { |header, attribute| [attribute, clean(row[header])] }.compact
      record = (key && values[key].present? && @find_in.find_by(key => values[key])) || @build.call
      action = record.new_record? ? :create : :update
      # As in the form: an update is authorized on the record as it is stored,
      # before the row's values touch it, so a row cannot rewrite the very
      # attribute a policy decides on. A create is judged with its values set.
      allowed = @authorize.call(action, record) if action == :update
      record.assign_attributes(values)
      allowed = @authorize.call(action, record) if action == :create

      if !allowed
        result.errors << [line, I18n.t("wibawa.flash.not_authorized")]
      elsif record.save
        action == :create ? result.created += 1 : result.updated += 1
      else
        result.errors << [line, record.errors.full_messages.to_sentence]
      end
    rescue ArgumentError, ActiveRecord::ActiveRecordError => e # e.g. a value that is not one of an enum's
      result.errors << [line, e.message]
    end

    # A leading apostrophe that the export added to defuse a
    # formula is taken off again, so an exported file imports unchanged.
    def clean(value)
      text = value.to_s.strip
      text = text[1..] if text.start_with?("'") && text[1..].match?(CsvExporter::FORMULA_PREFIX)
      text.presence
    end
  end
end
