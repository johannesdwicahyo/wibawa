module Wibawa
  module Generators
    # Wibawa's own tables get the app's kind of primary key. Its models inherit
    # from ApplicationRecord, so an app that keeps UUID keys (and perhaps
    # assigns them itself in ApplicationRecord) needs these tables to match:
    # a UUID written into an integer key is cut down to its first digits.
    module KeyType
      def self.included(base)
        base.class_option :primary_key_type, type: :string,
                                             desc: "Key type for the table (default: the app's config.generators primary_key_type)"
      end

      # ", id: :uuid" for create_table, or nothing for the database's default.
      def key_type_option
        type = options[:primary_key_type].presence || Rails.configuration.generators.options.dig(:active_record, :primary_key_type)
        ", id: :#{type}" if type
      end
    end
  end
end
