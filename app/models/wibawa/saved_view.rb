module Wibawa
  # A named index-page URL: scope, search, filters, sort and page size.
  # Table and switch come from `bin/rails g wibawa:saved_views`.
  class SavedView < (defined?(::ApplicationRecord) ? ::ApplicationRecord : ActiveRecord::Base)
    self.table_name = "wibawa_saved_views"

    # What a view may remember. Everything else in the URL is dropped.
    KEYS = %w[scope search q sort direction per_page].freeze

    validates :resource_key, :name, presence: true
    validates :name, length: { maximum: 60 }

    # Views belong to whoever saved them, who alone can rename, share or delete
    # them. Without a signed-in user (no authentication configured) every view
    # has no owner, so they are shared by everyone.
    scope :owned_by, ->(user) { where(owner: owner_key(user)) }
    scope :visible_to, ->(user) { owned_by(user).or(where(shared: true)) }

    before_save :one_default_per_owner, if: :default_view?

    # The view this user's index page opens on, if they chose one.
    # ponytail: a default is the owner's own; nobody can set one for the team,
    # or pick someone else's shared view. Add a per-user table if that is wanted.
    def self.default_for(resource_key, user)
      owned_by(user).find_by(resource_key: resource_key, default_view: true)
    end

    def owned_by?(user) = owner == self.class.owner_key(user)

    def self.owner_key(user)
      "#{user.class.name}:#{user.id}" if user.respond_to?(:id) && user.id
    end

    # Normalizes a query string or params hash to the allowed keys, in a stable order.
    # The default page size is left out: the index form always sends it, and
    # a view should match the same filters with or without it.
    def self.normalize(query, default_per_page: nil)
      params = query.is_a?(String) ? Rack::Utils.parse_nested_query(query) : query.to_h
      params = params.slice(*KEYS)
      # The filter form sends every filter, the empty ones too; a view keeps only the ones in use.
      params["q"] = params["q"].compact_blank if params["q"].respond_to?(:compact_blank)
      params.delete("per_page") if default_per_page && params["per_page"].to_i == default_per_page
      params.compact_blank.to_query
    end

    def self.default_per_page(resource) = resource.index_options[:per_page] || Wibawa.config.per_page

    def query=(value)
      super(self.class.normalize(value.to_s))
    end

    private

    def one_default_per_owner
      self.class.where(owner: owner, resource_key: resource_key, default_view: true).where.not(id: id).update_all(default_view: false)
    end
  end
end
