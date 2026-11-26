require "spec_helper"
require "tmpdir"
require "generators/wibawa/audit_log/audit_log_generator"
require "generators/wibawa/saved_views/saved_views_generator"
require "generators/wibawa/background_import/background_import_generator"

# What a mostly read-only panel over someone else's schema needs: money kept in
# cents, a default for which actions exist, secrets found by more than their
# name, and edits that do not overwrite each other. `rake postgres` runs the
# same ground on PostgreSQL with UUID keys.
RSpec.describe "Wibawa as an operator panel", type: :request do
  let!(:customer) { Customer.create!(name: "Sari") }
  let!(:order) { Order.create!(number: "A-1", customer: customer, total: 1_500_000) }

  after do
    Wibawa.config.default_actions = Wibawa::Configuration.new.default_actions
    Wibawa.config.currency = "USD"
    Wibawa.load!
  end

  describe "money kept as an integer of hundredths" do
    it "is shown divided by 100, right-aligned, under a label without the suffix" do
      Wibawa.config.currency = "IDR"
      Wibawa.resource(Order) { index { column :number and column :total, as: :cents } }
      get "/admin/orders"
      expect(response.body).to include("Rp 15.000")
      expect(response.body).to match(/<td class="[^"]*text-right[^"]*"><span[^>]*>Rp 15\.000/)

      expect(Wibawa::Column.new(:total_cents, { as: :cents }, nil).label).to eq("Total")
      expect(Wibawa::Column.new(:total_cents, {}, nil).label).to eq("Total cents")
      expect(Wibawa::Column.new(:total_cents, { as: :cents, label: "Paid" }, nil).label).to eq("Paid")

      get "/admin/orders.csv"
      expect(response.body).to include("1500000") # the export keeps the stored value
    end
  end

  describe "config.default_actions" do
    it "makes every resource read-only unless it says otherwise" do
      Wibawa.config.default_actions = %i[index show]
      Wibawa.load!
      Wibawa.resource(Customer) { actions :all }

      get "/admin/orders"
      expect(response.body).not_to include("New Order", "wb-row-form", "data-wb-select") # no new, no delete, no batch bar
      get "/admin/orders/#{order.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(">Edit<", ">Delete<")
      get "/admin/orders/new"
      expect(response).to have_http_status(:not_found)
      get "/admin/orders/#{order.id}/edit"
      expect(response).to have_http_status(:not_found)
      patch "/admin/orders/#{order.id}", params: { record: { number: "X" } }
      expect(response).to have_http_status(:not_found)
      delete "/admin/orders/#{order.id}"
      expect(response).to have_http_status(:not_found)
      post "/admin/orders/batch", params: { batch_action: "destroy", ids: [ order.id ] }
      expect(response).to have_http_status(:not_found)
      expect(order.reload.number).to eq("A-1")

      get "/admin/customers/new" # the one resource that asked for everything
      expect(response).to have_http_status(:ok)
    end
  end

  describe "what counts as a secret" do
    it "goes by name, hashes and keys included, and by what the model encrypts" do
      plain = Class.new
      encrypting = Class.new { def self.encrypted_attributes = %i[notes] }

      %w[pin_hash token_hash password_hash pdf_storage_key api_key password_digest otp_secret token].each do |name|
        expect(Wibawa::Resource.secret?(plain, name)).to be(true), name
      end
      %w[name hash key keyboard hashtag monkey status notes].each { |name| expect(Wibawa::Resource.secret?(plain, name)).to be(false), name }
      expect(Wibawa::Resource.secret?(encrypting, :notes)).to be(true)
      expect(Wibawa::Resource.secret?(encrypting, "name")).to be(false)
    end

    it "keeps them out of a resource's default pages and form" do
      ActiveRecord::Schema.define { create_table(:badges, force: true) { |t| t.string :name and t.string :pin_hash and t.string :notes } }
      stub_const("Badge", Class.new(ActiveRecord::Base) do
        self.table_name = "badges"
        def self.encrypted_attributes = %i[notes] # as `encrypts :notes` would report
      end)
      resource = Wibawa::Resource.new("Badge")
      shown = resource.index_columns.map(&:name) + resource.show_items.filter_map { |kind, column| column.name if kind == :row } + resource.permitted_attributes
      expect(shown.map(&:to_s).uniq - %w[id]).to eq(%w[name])
    ensure
      ActiveRecord::Schema.define { drop_table :badges, if_exists: true }
    end
  end

  describe "optimistic locking" do
    before do
      ActiveRecord::Schema.define { create_table(:memos, force: true) { |t| t.string :title and t.integer :lock_version, default: 0, null: false } }
      stub_const("Memo", Class.new(ActiveRecord::Base) { self.table_name = "memos" })
      Wibawa.resource(Memo)
    end
    after { ActiveRecord::Schema.define { drop_table :memos, if_exists: true } }

    it "refuses to save over a change made since the form was opened, and keeps what was typed" do
      memo = Memo.create!(title: "First")
      get "/admin/memos/#{memo.id}/edit"
      expect(response.body).to match(/<input[^>]*type="hidden"[^>]*name="record\[lock_version\]"|<input[^>]*name="record\[lock_version\]"[^>]*type="hidden"/)
      expect(response.body).not_to include("Lock version") # carried, never shown as a field

      memo.update!(title: "Theirs")
      patch "/admin/memos/#{memo.id}", params: { record: { title: "Mine", lock_version: 0 } }
      expect(response).to have_http_status(:conflict)
      expect(response.body).to include("Someone else changed this record", 'value="Mine"')
      expect(memo.reload.title).to eq("Theirs")

      patch "/admin/memos/#{memo.id}", params: { record: { title: "Mine", lock_version: memo.lock_version } }
      expect(response).to have_http_status(:see_other)
      expect(memo.reload.title).to eq("Mine")

      get "/admin/memos/new"
      expect(response.body).not_to include("record[lock_version]") # nothing to be stale against yet
    end
  end

  describe "searching a model whose key is not a number" do
    it "only compares a term with a column it could be a value of" do
      uuid = "019a2b3c-4d5e-7f60-8a9b-0c1d2e3f4a5b"
      expect(Wibawa::Query.comparable?(:uuid, uuid)).to be(true)
      expect(Wibawa::Query.comparable?(:uuid, "123")).to be(false) # PostgreSQL raises on id = '123' for a uuid column
      expect(Wibawa::Query.comparable?(:integer, "123")).to be(true)
      expect(Wibawa::Query.comparable?(:integer, uuid)).to be(false)
      expect(Wibawa::Query.comparable?(:integer, "9" * 30)).to be(false) # out of range for the column
      expect(Wibawa::Query.comparable?(:decimal, "12.5")).to be(true)
      expect(Wibawa::Query.comparable?(:string, "anything")).to be(true)

      expect(Wibawa::Query.key_like?(Customer, customer.id.to_s)).to be(true)
      expect(Wibawa::Query.key_like?(Customer, "sari")).to be(false)
    end
  end

  describe "Wibawa's own tables" do
    it "take the app's key type, or the one asked for" do
      migration = lambda do |generator, *arguments|
        Dir.mktmpdir do |dir|
          generator.start([ *arguments, "--quiet" ], destination_root: dir)
          File.read(Dir[File.join(dir, "db/migrate/*.rb")].first)[/create_table .*$/]
        end
      end

      expect(migration.(Wibawa::Generators::AuditLogGenerator)).to eq("create_table :wibawa_audit_entries do |t|")
      expect(migration.(Wibawa::Generators::AuditLogGenerator, "--primary-key-type=uuid")).to eq("create_table :wibawa_audit_entries, id: :uuid do |t|")
      expect(migration.(Wibawa::Generators::SavedViewsGenerator, "--primary-key-type=uuid")).to eq("create_table :wibawa_saved_views, id: :uuid do |t|")

      Rails.configuration.generators.options[:active_record] = (Rails.configuration.generators.options[:active_record] || {}).merge(primary_key_type: :uuid)
      expect(migration.(Wibawa::Generators::BackgroundImportGenerator)).to eq("create_table :wibawa_imports, id: :uuid do |t|")
    ensure
      Rails.configuration.generators.options[:active_record]&.delete(:primary_key_type)
    end
  end
end
