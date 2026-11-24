module Wibawa
  # A named index-page URL: scope, search, filters, sort and page size.
  # Table and switch come from `bin/rails g wibawa:saved_views`.
  class SavedView < (defined?(::ApplicationRecord) ? ::ApplicationRecord : ActiveRecord::Base)
    self.table_name = "wibawa_saved_views"

    # What a view may remember. Everything else in the URL is dropped.
    KEYS = %w[scope search q sort direction per_page].freeze

    validates :resource_key, :name, presence: true
    validates :name, length: { maximum: 60 }

    # Views belong to whoever saved them. Without a signed-in user (no
    # authentication configured) they are shared by everyone.
    scope :visible_to, ->(user) { where(owner: owner_key(user)) }

    def self.owner_key(user)
      "#{user.class.name}:#{user.id}" if user.respond_to?(:id) && user.id
    end

    # Normalizes a query string or params hash to the allowed keys, in a stable order.
    def self.normalize(query)
      params = query.is_a?(String) ? Rack::Utils.parse_nested_query(query) : query.to_h
      params.slice(*KEYS).compact_blank.to_query
    end

    def query=(value)
      super(self.class.normalize(value.to_s))
    end
  end
end
