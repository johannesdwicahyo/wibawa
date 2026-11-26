# Runs the admin against PostgreSQL with UUID primary keys that the app
# generates itself, money in integer cents, an encrypted column, jsonb, soft
# delete and optimistic locking. The spec suite runs on SQLite with integer
# keys, which forgives things PostgreSQL does not.
#
#   bundle exec rake postgres        # needs a PostgreSQL server; DATABASE_URL to point at one
ENV["RAILS_ENV"] = "test"
database = "wibawa_postgres_check"
ENV["DATABASE_URL"] ||= "postgres:///#{database}"

require "pg"
require "securerandom"
require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "active_job/railtie"
require "propshaft"
require "wibawa"
require "rack/mock"

begin
  admin = PG.connect(ENV["DATABASE_URL"].sub(%r{/[^/]*\z}, "/postgres"))
  name = ENV["DATABASE_URL"][%r{/([^/?]+)(\?|\z)}, 1]
  admin.exec("SET client_min_messages = warning")
  admin.exec(%(DROP DATABASE IF EXISTS "#{name}"))
  admin.exec(%(CREATE DATABASE "#{name}"))
  admin.close
rescue PG::Error => e
  abort "PostgreSQL: cannot prepare the database (#{e.message.lines.first.strip}). Is a server running?"
end

class PostgresApp < Rails::Application
  config.root = Dir.mktmpdir("wibawa-postgres")
  config.load_defaults Rails::VERSION::STRING.to_f
  config.eager_load = false
  config.secret_key_base = "test"
  config.hosts.clear
  config.logger = Logger.new(nil)
  config.action_dispatch.show_exceptions = :none
  config.action_controller.allow_forgery_protection = false
  config.active_job.queue_adapter = :inline
  config.active_record.encryption.primary_key = "p" * 32
  config.active_record.encryption.deterministic_key = "d" * 32
  config.active_record.encryption.key_derivation_salt = "s" * 32
end

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  before_create { self.id ||= SecureRandom.uuid } # the app makes its own keys; the column has no default
end

class Operator < ApplicationRecord; end

class Business < ApplicationRecord
  has_many :staff_members
  has_many :orders
  scope :active, -> { where(deleted_at: nil) }
end

class StaffMember < ApplicationRecord
  belongs_to :business
  encrypts :pin_hash
end

class Order < ApplicationRecord
  belongs_to :business
  has_many :payments
  validates :number, presence: true
end

class Payment < ApplicationRecord
  belongs_to :order
end

PostgresApp.initialize!

ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:operators, id: :uuid, default: nil) { |t| t.string :name }
  create_table :businesses, id: :uuid, default: nil do |t|
    t.string :name
    t.jsonb :settings, default: {}
    t.datetime :deleted_at
    t.integer :lock_version, default: 0, null: false
    t.timestamps
  end
  create_table :staff_members, id: :uuid, default: nil do |t|
    t.references :business, type: :uuid
    t.string :name
    t.string :pin_hash
    t.string :token_hash
  end
  create_table :orders, id: :uuid, default: nil do |t|
    t.references :business, type: :uuid
    t.string :number
    t.string :status, default: "open"
    t.integer :total_cents, default: 0
    t.timestamps
  end
  create_table :payments, id: :uuid, default: nil do |t|
    t.references :order, type: :uuid
    t.integer :amount_cents
    t.string :method
  end
  # Wibawa's own tables. Its models inherit from ApplicationRecord and so get their keys from it too,
  # which is why these must have the app's key type (the generators follow config.generators).
  create_table :wibawa_saved_views, id: :uuid, default: nil do |t|
    t.string :resource_key, null: false
    t.string :name, null: false
    t.text :query, null: false, default: ""
    t.string :owner
    t.boolean :shared, null: false, default: false
    t.boolean :default_view, null: false, default: false
    t.timestamps
  end
  create_table :wibawa_audit_entries, id: :uuid, default: nil do |t|
    t.string :actor
    t.string :actor_label
    t.string :action, null: false
    t.string :via, null: false
    t.string :resource_key, null: false
    t.string :record_id
    t.string :record_label
    t.json :data
    t.datetime :created_at, null: false
  end
  create_table :wibawa_imports, id: :uuid, default: nil do |t|
    t.string :resource_key, null: false
    t.string :owner
    t.string :user_gid
    t.string :filename
    t.string :status, null: false, default: "queued"
    t.boolean :dry_run, null: false, default: false
    t.binary :file, limit: 100.megabytes
    t.json :result
    t.datetime :started_at
    t.datetime :finished_at
    t.timestamps
  end
end

OPERATOR = Operator.create!(name: "Ops")
Wibawa.configure do |config|
  config.parent_controller = "ActionController::Base"
  config.authenticate_with :none
  config.current_user = -> { OPERATOR }
  config.currency = "IDR"
  config.load_paths = []
  config.saved_views = true
  config.audit_log = true
  config.background_import = true
  config.default_actions = %i[index show] # a read-only panel,
end
Wibawa.load!
Wibawa.resource Business do
  actions :all # with one resource that may be edited
  search :name
  filter :orders
  form { fields :name }
end
Wibawa.resource StaffMember # nothing declared: the default pages
Wibawa.resource Order do
  actions :all
  search :number, :id, "business.name"
  filter :business
  filter :payments
  filter "payments.amount_cents"
  filter :status
  import key: :number
  index do
    id_column
    column :number
    column :business
    column :total_cents, as: :cents
    column :created_at
    actions
  end
  form { fields :number, :business, :status, :total_cents }
end
Wibawa.resource Payment
PostgresApp.routes.draw { mount Wibawa::Engine, at: "/ops" }

toko = Business.create!(name: "Toko Sari", settings: { "npwp" => "01.234.567.8-901.000" })
warung = Business.create!(name: "Warung Budi", deleted_at: Time.current)
staff = StaffMember.create!(business: toko, name: "Dewi", pin_hash: "pin-secret-1", token_hash: "token-secret-2")
paid = Order.create!(business: toko, number: "ORD-00123", total_cents: 1_500_000, status: "paid")
open_order = Order.create!(business: warung, number: "ORD-00456", total_cents: 25_000)
payment = Payment.create!(order: paid, amount_cents: 1_500_000, method: "qris")

BROWSER = Rack::MockRequest.new(PostgresApp)
FAILED = []
PASSED = []

def request(verb, path, params = nil)
  BROWSER.public_send(verb, path, "HTTP_HOST" => "localhost", params: params)
end

def check(name)
  problem = yield
  problem ? FAILED << "#{name}: #{problem}" : PASSED << name
rescue StandardError, ScriptError => e
  FAILED << "#{name}: #{e.class}: #{e.message.lines.first.to_s.strip[0, 220]}"
end

def page(path, includes: [], excludes: [], status: 200)
  response = request(:get, path)
  return "HTTP #{response.status}" unless response.status == status

  missing = Array(includes).reject { |text| response.body.include?(text.to_s) }
  leaked = Array(excludes).select { |text| response.body.include?(text.to_s) }
  return "missing #{missing.inspect}" if missing.any?

  "shows #{leaked.inspect}" if leaked.any?
end

def csv_numbers(query) = request(:get, "/ops/orders.csv?#{query.to_query}").body.lines.drop(1).map { |line| line.split(",")[1] }.sort

check("dashboard") { page("/ops") }
check("index, newest first by a UUID key") { page("/ops/orders", includes: %w[ORD-00123 ORD-00456 Toko]) }
check("money kept in cents") { page("/ops/orders", includes: [ "Rp 15.000", "Rp 250" ], excludes: [ "1.500.000", "Total cents" ]) }
check("sort by a column") { page("/ops/orders?sort=number&direction=asc", includes: "ORD-00123") }
check("record page") { page("/ops/orders/#{paid.id}", includes: [ "ORD-00123", paid.id ]) }
check("an id that is not a UUID is a 404, not an error") { page("/ops/orders/123", status: 404) }
check("search by text") { csv_numbers(search: "00123") == [ "ORD-00123" ] ? nil : "wrong rows" }
check("search by a number, which no uuid column can equal") { csv_numbers(search: "123") == [ "ORD-00123" ] ? nil : "wrong rows" }
check("search by a whole id") { csv_numbers(search: open_order.id) == [ "ORD-00456" ] ? nil : "wrong rows" }
check("search through an association") { csv_numbers(search: "warung") == [ "ORD-00456" ] ? nil : "wrong rows" }
check("belongs_to filter") { csv_numbers(q: { business: toko.id }) == [ "ORD-00123" ] ? nil : "wrong rows" }
check("belongs_to filter with a value that is not a UUID") { csv_numbers(q: { business: "x" }) == [] ? nil : "wrong rows" }
check("has_many filter") { csv_numbers(q: { payments: payment.id }) == [ "ORD-00123" ] ? nil : "wrong rows" }
check("has_many filter with a value that is not a UUID") { csv_numbers(q: { payments: "12" }) == [] ? nil : "wrong rows" }
check("filter on an associated column") { csv_numbers(q: { "payments.amount_cents_from" => 1000 }) == [ "ORD-00123" ] ? nil : "wrong rows" }
check("filter chips and controls") { page("/ops/orders?#{{ q: { business: toko.id, status: 'paid' } }.to_query}", includes: "Toko Sari") }
check("command palette search") { page("/ops/-/search?q=123", includes: "ORD-00123") }
check("searchable select options, by text and by a number") do
  page("/ops/orders/options/Business?q=toko", includes: "Toko Sari") || page("/ops/orders/options/Business?q=123") ||
    page("/ops/payments/options/Order?q=123") || page("/ops/businesses/options/Order?q=#{paid.id}", includes: "ORD-00123") # Order searches :id
end

check("default pages leave out what the model encrypts, and *_hash") do
  page("/ops/staff_members", includes: "Dewi", excludes: %w[pin-secret-1 token-secret-2 Pin\ hash Token\ hash]) ||
    page("/ops/staff_members/#{staff.id}", includes: "Dewi", excludes: %w[pin-secret-1 token-secret-2])
end
check("a read-only panel by default") do
  page("/ops/payments", includes: "qris", excludes: [ "New Payment", "wb-row-form", "data-wb-select" ]) ||
    page("/ops/payments/new", status: 404) || page("/ops/payments/#{payment.id}/edit", status: 404) ||
    (request(:delete, "/ops/payments/#{payment.id}").status == 404 && Payment.exists?(payment.id) ? nil : "a payment could be deleted")
end
check("jsonb on a record page") { page("/ops/businesses/#{toko.id}", includes: "npwp") }

check("create, with the app making the key") do
  response = request(:post, "/ops/orders", { record: { number: "ORD-00789", business_id: toko.id, total_cents: 500 } })
  created = Order.find_by(number: "ORD-00789")
  response.status == 303 && created&.id.to_s.match?(Wibawa::Query::UUID) ? nil : "HTTP #{response.status}"
end
check("update") do
  response = request(:patch, "/ops/orders/#{open_order.id}", { record: { status: "paid" } })
  response.status == 303 && open_order.reload.status == "paid" ? nil : "HTTP #{response.status}"
end
check("a stale edit is refused, and says so") do
  form = request(:get, "/ops/businesses/#{toko.id}/edit").body
  version = form[/name="record\[lock_version\]"[^>]*value="(\d+)"/, 1] || form[/value="(\d+)"[^>]*name="record\[lock_version\]"/, 1]
  next "the form carries no lock_version" unless version

  toko.update!(name: "Toko Sari Jaya") # someone else saves first
  response = request(:patch, "/ops/businesses/#{toko.id}", { record: { name: "Mine", lock_version: version } })
  response.status == 409 && response.body.include?("Someone else changed") && toko.reload.name == "Toko Sari Jaya" ? nil : "HTTP #{response.status}, name #{toko.reload.name}"
end
check("batch delete by UUID") do
  doomed = Order.create!(business: toko, number: "ORD-DOOM")
  response = request(:post, "/ops/orders/batch", { batch_action: "destroy", ids: [ doomed.id ] })
  response.status == 303 && !Order.exists?(doomed.id) ? nil : "HTTP #{response.status}"
end
check("delete") do
  doomed = Order.create!(business: toko, number: "ORD-DOOM2")
  request(:delete, "/ops/orders/#{doomed.id}").status == 303 && !Order.exists?(doomed.id) ? nil : "still there"
end

check("audit log, with UUIDs for the record and the operator") do
  entry = Wibawa::AuditEntry.where(action: "update", resource_key: "orders").last
  next "no entry" unless entry
  next "actor #{entry.actor.inspect}" unless entry.actor == "Operator:#{OPERATOR.id}" && entry.record_id == open_order.id

  page("/ops/audit_log", includes: "Ops") || page("/ops/audit_log?#{{ q: { resource_key: 'orders', record_id: open_order.id } }.to_query}", includes: "ORD-00456")
end
check("saved views, owned by a UUID user") do
  request(:post, "/ops/orders/views", { name: "Paid", query: "q%5Bstatus%5D=paid" })
  view = Wibawa::SavedView.last
  view&.owner == "Operator:#{OPERATOR.id}" ? page("/ops/orders", includes: ">Paid<") : "owner #{view&.owner.inspect}"
end
check("CSV import by key, with a UUID foreign key") do
  Dir.mktmpdir do |dir|
    File.write(File.join(dir, "o.csv"), "number,business_id,total_cents\nORD-IMP1,#{toko.id},700\nORD-00123,,900\n")
    upload = Rack::Multipart::UploadedFile.new(File.join(dir, "o.csv"), "text/csv")
    env = Rack::MockRequest.env_for("/ops/orders/import", "HTTP_HOST" => "localhost", method: "POST", params: { file: upload })
    status, = PostgresApp.call(env)
    status == 303 && Order.find_by(number: "ORD-IMP1")&.business == toko && paid.reload.total_cents == 900 ? nil : "HTTP #{status}"
  end
end
check("a background import, run as a UUID user found again by the job") do
  import = Wibawa::Import.start!(Wibawa.registry.fetch("orders"), OPERATOR, "number,business_id\nORD-BG1,#{toko.id}\n", filename: "p.csv", dry_run: true)
  import.reload.status == "finished" && import.user_gid.include?(OPERATOR.id) ? nil : "status #{import.reload.status}: #{import.result.inspect[0, 160]}"
end
check("Wibawa's own records get UUID keys from the app") do
  ids = [ Wibawa::AuditEntry, Wibawa::SavedView, Wibawa::Import ].flat_map { |model| model.limit(3).pluck(:id) }
  ids.size >= 5 && ids.all? { |id| id.to_s.match?(Wibawa::Query::UUID) } ? page("/ops/orders/imports/#{Wibawa::Import.order(:created_at).last.id}", includes: [ "p.csv", "would create 1" ]) : "ids #{ids.first(3).inspect}"
end
check("MCP is closed until it is configured") { request(:post, "/ops/mcp").status == 404 ? nil : "it answered" }
check("related records under a policy scope") do
  adapter = Class.new(Wibawa::Authorization::Allow) { def scope(relation) = relation.klass == Business ? relation.where(deleted_at: nil) : relation }
  Wibawa.config.authorization = adapter
  problem = page("/ops/orders", includes: [ "Toko Sari Jaya", "##{warung.id}" ], excludes: "Warung Budi")
  response = request(:patch, "/ops/orders/#{paid.id}", { record: { business_id: warung.id } })
  problem || (response.status == 422 && paid.reload.business == toko ? nil : "a hidden business could be chosen (HTTP #{response.status})")
ensure
  Wibawa.config.authorization = nil
end

ActiveRecord::Base.connection_pool.disconnect!
cleanup = PG.connect(ENV["DATABASE_URL"].sub(%r{/[^/]*\z}, "/postgres"))
cleanup.exec(%(DROP DATABASE IF EXISTS "#{ENV['DATABASE_URL'][%r{/([^/?]+)(\?|\z)}, 1]}"))
cleanup.close

abort "PostgreSQL: #{FAILED.size} of #{FAILED.size + PASSED.size} checks failed\n  " + FAILED.join("\n  ") if FAILED.any?
puts "PostgreSQL with UUID keys: #{PASSED.size} checks OK"
