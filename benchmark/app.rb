# One Rails app with the same orders table behind three admins:
#   /wibawa/orders, /activeadmin/orders, /administrate/orders
# Each shows the same six columns, eager-loads the customer, and has no
# filters, search or sign-in, so what is timed is the index page itself.
ENV["RAILS_ENV"] = "production"
ENV["DATABASE_URL"] = "sqlite3::memory:"

require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "wibawa"
require "activeadmin"
require "administrate"

module Bench
  class Application < Rails::Application
    config.root = __dir__
    config.load_defaults 8.1
    config.eager_load = true # as in production: nothing is loaded or compiled during a timed request
    config.secret_key_base = "benchmark"
    config.hosts.clear
    config.logger = Logger.new(nil)
    config.consider_all_requests_local = true
    config.action_controller.perform_caching = false
    config.active_record.maintain_test_schema = false
    # Only the HTML is timed, so there is no asset pipeline: every admin's asset tags come out as plain
    # paths at no cost, as a lookup in a precompiled manifest would. ActiveAdmin 3 and Wibawa add to this setting as they boot.
    config.assets = ActiveSupport::OrderedOptions.new.tap { |assets| assets.precompile = assets.paths = [] }
  end
end

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end

class Customer < ApplicationRecord
  has_many :orders

  def self.ransackable_attributes(_auth = nil) = column_names
  def self.ransackable_associations(_auth = nil) = []
end

class Order < ApplicationRecord
  belongs_to :customer
  enum :status, { pending: 0, paid: 1, shipped: 2 }

  def self.ransackable_attributes(_auth = nil) = column_names
  def self.ransackable_associations(_auth = nil) = %w[customer]
end

class ApplicationController < ActionController::Base
end

# ---- Wibawa ----------------------------------------------------------------
Wibawa.configure do |config|
  config.parent_controller = "ActionController::Base"
  config.authenticate_with :none
  config.load_paths = []
  config.max_per_page = 500
end

# ---- ActiveAdmin -----------------------------------------------------------
ActiveAdmin.setup do |config|
  config.load_paths = [ File.join(__dir__, "active_admin") ]
  config.authentication_method = false
  config.current_user_method = false
  config.default_namespace = :activeadmin
  config.batch_actions = true # its default
  config.comments = false     # needs a table of its own, and is not on the index page
  config.filters = false      # the others show none
end

# ---- Administrate ----------------------------------------------------------
require "administrate/base_dashboard"

class CustomerDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = { id: Field::Number, name: Field::String }.freeze
  COLLECTION_ATTRIBUTES = %i[id name].freeze
  SHOW_PAGE_ATTRIBUTES = %i[id name].freeze
  FORM_ATTRIBUTES = %i[name].freeze

  def display_resource(customer) = customer.name
end

class OrderDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number, number: Field::String, customer: Field::BelongsTo,
    status: Field::Select.with_options(collection: ->(field) { field.resource.class.statuses.keys }),
    total: Field::Number.with_options(prefix: "$", decimals: 2), created_at: Field::DateTime
  }.freeze
  COLLECTION_ATTRIBUTES = %i[id number customer status total created_at].freeze
  SHOW_PAGE_ATTRIBUTES = COLLECTION_ATTRIBUTES
  FORM_ATTRIBUTES = %i[number customer status total].freeze

  def display_resource(order) = order.number
end

Bench::Application.initialize!

# Administrate's base controller comes from its engine, which is loaded by now.
module Administrated
  class ApplicationController < Administrate::ApplicationController
  end

  class OrdersController < ApplicationController
  end

  class CustomersController < ApplicationController
  end
end

ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:customers) { |t| t.string :name }
  create_table :orders do |t|
    t.string :number
    t.integer :status, default: 0
    t.decimal :total, precision: 12, scale: 2
    t.references :customer
    t.timestamps
  end
end

customers = Array.new(50) { |i| Customer.create!(name: "Customer #{i + 1}") }
now = Time.utc(2026, 1, 1)
Order.insert_all!(Array.new(1000) do |i|
  { number: format("ORD-%05d", i + 1), status: i % 3, total: 10 + (i * 7 % 990), customer_id: customers[i % 50].id,
    created_at: now + i * 3600, updated_at: now + i * 3600 }
end)

Wibawa.resource Customer
Wibawa.resource Order do
  index sort: { id: :desc } do
    id_column
    column :number
    column :customer
    column :status
    column :total, as: :money
    column :created_at
    actions
  end
end

# ActiveAdmin's two resources are in benchmark/active_admin, which it loads itself when the routes are drawn.

Rails.application.routes.draw do
  mount Wibawa::Engine, at: "/wibawa"
  ActiveAdmin.routes(self)
  namespace :administrated, path: "administrate" do
    resources :orders
    resources :customers
    root to: "orders#index"
  end
end
