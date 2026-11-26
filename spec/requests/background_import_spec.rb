require "spec_helper"
require "tmpdir"
require "generators/wibawa/background_import/background_import_generator"

RSpec.describe "Wibawa background CSV import", type: :request do
  include ActiveJob::TestHelper

  let!(:customer) { Customer.create!(name: "Sari") }
  let!(:order) { Order.create!(number: "A-1", customer: customer) }
  let(:big) { "number,status,customer_id\n" + (1..5).map { |n| "N-#{n},paid,#{customer.id}\n" }.join }

  before do
    stub_const("Wibawa::CsvImporter::MAX_ROWS", 3) # "large" is four rows here
    Wibawa.config.background_import = true
  end

  after do
    Wibawa.config.background_import = false
    Wibawa.config.audit_log = false
    Wibawa.config.authorization = nil
    Wibawa.config.current_user = :current_user
  end

  def upload(csv, **params)
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "orders.csv"), csv)
      post "/admin/orders/import", params: { file: Rack::Test::UploadedFile.new(File.join(dir, "orders.csv"), "text/csv"), **params }
    end
  end

  def sign_in(user) = Wibawa.config.current_user = -> { user }
  def status_page = response.body[/<div[^>]*data-wb-import-status.*\z/m]

  it "refuses a large file when it is off" do
    Wibawa.config.background_import = false
    upload big
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("more than 3 rows")
    expect(Wibawa::Import.count).to eq(0)
  end

  it "stores a large file, imports it in a job, and shows the result on a page that waited for it" do
    Wibawa.config.audit_log = true
    upload big
    import = Wibawa::Import.last
    expect(response).to redirect_to("/admin/orders/imports/#{import.id}")
    expect(import).to have_attributes(status: "queued", resource_key: "orders", filename: "orders.csv", dry_run: false, file: big)
    expect(Order.count).to eq(1)

    follow_redirect!
    expect(status_page).to include('data-wb-import-status="queued"', "data-wb-reload", "Waiting to start", "Check again")
    expect(response.body).not_to include("http-equiv")

    perform_enqueued_jobs
    expect(Order.where(status: :paid).pluck(:number)).to eq(%w[N-1 N-2 N-3 N-4 N-5])
    expect(import.reload).to have_attributes(status: "finished", file: nil, result: include("created" => 5, "updated" => 0))
    expect(Wibawa::AuditEntry.last).to have_attributes(action: "import", resource_key: "orders", data: { "created" => 5, "updated" => 0 })

    get "/admin/orders/imports/#{import.id}"
    expect(status_page).to include('data-wb-import-status="finished"', "Import finished: 5 created, 0 updated.")
    expect(status_page).not_to include("data-wb-reload")

    get "/admin/orders/import"
    expect(response.body).to include("Recent background imports", %(href="/admin/orders/imports/#{import.id}"), "Finished", "imported in the background")

    Wibawa::ImportJob.perform_now(import.id) # delivered twice: nothing more happens
    expect(Order.count).to eq(6)
  end

  it "still imports a small file at once" do
    upload "number,status,customer_id\nS-1,paid,#{customer.id}\n"
    expect(response).to redirect_to("/admin/orders")
    expect(Order.find_by(number: "S-1")).to be_paid
    expect(Wibawa::Import.count).to eq(0)
  end

  it "keeps nothing when a row is wrong, and lists the lines" do
    upload big.sub("N-3,paid", ",paid")
    perform_enqueued_jobs
    follow_redirect!
    expect(Wibawa::Import.last.status).to eq("finished")
    expect(status_page).to include("Nothing was imported", "Line 4:")
    expect(Order.count).to eq(1)
  end

  it "checks a large file without keeping anything" do
    Wibawa.config.audit_log = true
    upload big, dry_run: "1"
    perform_enqueued_jobs
    follow_redirect!
    expect(status_page).to include("would create 5 and update 0", "The first 5 rows", "N-5")
    expect(Order.count).to eq(1)
    expect(Wibawa::AuditEntry.count).to eq(0)
  end

  it "runs as the user who started it, and shows the import to nobody else" do
    other = Customer.create!(name: "Budi")
    sign_in(customer)
    Wibawa.config.authorization = ->(user, action, _subject) { user == customer || action != :create }
    upload big
    import = Wibawa::Import.last
    expect(import).to have_attributes(owner: "Customer:#{customer.id}", user_gid: customer.to_global_id.to_s)

    sign_in(other)
    get "/admin/orders/imports/#{import.id}"
    expect(response).to have_http_status(:not_found)

    perform_enqueued_jobs # the job is the uploader, who may create, whoever is signed in by then
    expect(Order.count).to eq(6)
  end

  it "imports nothing when the user may not create by the time the job runs, or is gone" do
    sign_in(customer)
    upload big
    Wibawa.config.authorization = ->(_user, action, _subject) { action != :create }
    perform_enqueued_jobs
    expect(Wibawa::Import.last.result["errors"].first).to eq([ 2, "You don't have permission to do that." ])

    Wibawa.config.authorization = nil
    uploader = Customer.create!(name: "Leaving")
    sign_in(uploader)
    upload big
    uploader.destroy
    perform_enqueued_jobs
    expect(Wibawa::Import.last).to have_attributes(status: "failed", file: nil)
    expect(Order.count).to eq(1)

    sign_in(nil)
    get "/admin/orders/imports/#{Wibawa::Import.last.id}"
    expect(response).to have_http_status(:not_found) # it belonged to the user who is gone
  end

  it "never runs a resource with controller overrides, or a user a job cannot find, in the background" do
    Wibawa.registry.fetch("orders").controller_blocks << proc { }
    upload big
    expect(response).to have_http_status(:unprocessable_entity)
    Wibawa.registry.fetch("orders").controller_blocks.pop

    sign_in(Struct.new(:id, :name).new(1, "Sari"))
    upload big
    expect(response).to have_http_status(:unprocessable_entity)
    expect(Wibawa::Import.count).to eq(0)
  end

  it "has a generator for the table" do
    Dir.mktmpdir do |dir|
      Wibawa::Generators::BackgroundImportGenerator.start(%w[--quiet], destination_root: dir)
      expect(File.read(Dir[File.join(dir, "db/migrate/*_create_wibawa_imports.rb")].first)).to include("create_table :wibawa_imports", "t.binary :file")
    end
  end
end
