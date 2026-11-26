require "spec_helper"
require "pundit"
require "action_policy"
require "rails/generators"
require "generators/wibawa/component/component_generator"

# Things the README says work, each run for real.
RSpec.describe "README promises", type: :request do
  let!(:customer) { Customer.create!(name: "Sari") }
  let!(:order) { Order.create!(number: "A-1", customer: customer, total: 10) }
  let!(:paid) { Order.create!(number: "A-2", customer: customer, total: 15, status: :paid) }

  describe "Active Storage and Action Text, on a model with no form, show or index block" do
    let(:photo) { Rack::Test::UploadedFile.new("spec/fixtures/files/kawung.png", "image/png") }
    let(:notes) { Rack::Test::UploadedFile.new("spec/fixtures/files/notes.txt", "text/plain") }

    it "offers a file field per attachment and an editor for rich text" do
      get "/admin/products/new"
      expect(response.body).to include('type="file" name="record[photo]"', 'name="record[documents][]"',
                                       "<trix-editor", 'enctype="multipart/form-data"')
    end

    it "saves uploads and rich text, and shows them" do
      post "/admin/products", params: { record: { name: "Kain", photo: photo, documents: [ notes ], description: "<div>Hand <strong>drawn</strong></div>" } }
      product = Product.last
      expect(product.photo).to be_attached
      expect(product.documents.map { |file| file.filename.to_s }).to eq([ "notes.txt" ])
      expect(product.description.to_plain_text).to eq("Hand drawn")

      get "/admin/products/#{product.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<img", "kawung.png", "1 file", 'class="wb-rich"', "Hand <strong>drawn</strong>") # rich text whole and formatted

      get "/admin/products/#{product.id}/edit"
      expect(response.body).to include("kawung.png", "Hand &lt;strong&gt;drawn&lt;/strong&gt;").or include("kawung.png", "<strong>drawn</strong>")

      get "/admin/products"
      expect(response).to have_http_status(:ok)
      get "/admin/products.csv"
      expect(response.body).to include("Kain")
    end
  end

  shared_examples "a policy adapter" do
    it "scopes the index, hides what is not allowed, refuses the rest and falls back for unnamed actions" do
      get "/admin/orders"
      expect(response.body).to include("A-1")
      expect(response.body).not_to include("A-2") # the policy scope leaves out paid orders
      expect(response.body).not_to include("New Order") # create? is false

      get "/admin/orders/new"
      expect(response).to have_http_status(:forbidden)
      expect { post "/admin/orders", params: { record: { number: "X", customer_id: customer.id } } }.not_to change(Order, :count)

      get "/admin/orders/#{order.id}/edit"
      expect(response).to have_http_status(:ok)
      get "/admin/orders.csv" # no export? rule: falls back to index?
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("A-1")
      expect(response.body).not_to include("A-2")

      post "/admin/orders/#{order.id}/actions/pay" # no pay? rule: falls back to update?
      expect(order.reload).to be_paid
      order.pending!

      delete "/admin/orders/#{order.id}"
      expect(Order.exists?(order.id)).to be(true) # destroy? is false
      expect { get "/admin/orders/#{paid.id}" }.not_to raise_error
      expect(response).to have_http_status(:not_found) # outside the scope
    end
  end

  describe "Pundit" do
    before do
      stub_const("ApplicationPolicy", Class.new do
        attr_reader :user, :record

        def initialize(user, record) = (@user, @record = user, record)
        %i[index? show? create? update? destroy?].each { |rule| define_method(rule) { true } }
      end)
      stub_const("ApplicationPolicy::Scope", Class.new do
        def initialize(user, scope) = (@user, @scope = user, scope)
        def resolve = @scope.all
      end)
      stub_const("OrderPolicy", Class.new(ApplicationPolicy) do
        def create? = false
        def destroy? = false
      end)
      stub_const("OrderPolicy::Scope", Class.new(ApplicationPolicy::Scope) { def resolve = @scope.pending })
      %w[Customer LineItem Product].each do |name|
        stub_const("#{name}Policy", Class.new(ApplicationPolicy))
        stub_const("#{name}Policy::Scope", Class.new(ApplicationPolicy::Scope))
      end
      stub_const("Wibawa::ReportPolicy", Class.new(ApplicationPolicy))
      stub_const("Wibawa::PagePolicy", Class.new(ApplicationPolicy))
      Wibawa.config.authorization = :pundit
    end

    it_behaves_like "a policy adapter"
  end

  describe "ActionPolicy" do
    before do
      stub_const("ApplicationPolicy", Class.new(ActionPolicy::Base) do
        authorize :user, allow_nil: true
        %i[index? show? create? update? destroy?].each { |rule| define_method(rule) { true } }
        scope_for(:active_record_relation) { |relation| relation }
      end)
      stub_const("OrderPolicy", Class.new(ApplicationPolicy) do
        def create? = false
        def destroy? = false
        scope_for(:active_record_relation) { |relation| relation.pending }
      end)
      %w[Customer LineItem Product].each { |name| stub_const("#{name}Policy", Class.new(ApplicationPolicy)) }
      stub_const("Wibawa::ReportPolicy", Class.new(ApplicationPolicy))
      stub_const("Wibawa::PagePolicy", Class.new(ApplicationPolicy))
      Wibawa.config.authorization = :action_policy
    end

    it_behaves_like "a policy adapter"
  end

  describe "the Indonesian locale" do
    around { |example| I18n.with_locale(:id, &example) }

    # That it has every English key is checked for all locales in spec/unit/locales_spec.rb.
    it "renders every kind of page without a missing translation" do
      [ "/admin", "/admin/orders", "/admin/orders/#{order.id}", "/admin/orders/#{order.id}/edit", "/admin/orders/new", "/admin/orders/import",
       "/admin/reports/orders_by_status", "/admin/pages/maintenance", "/admin/products/new" ].each do |path|
        get path
        expect(response).to have_http_status(:ok), path
        expect(response.body).not_to match(/translation missing|Translation missing/i), path
      end
      expect(response.body).to include('lang="id"')
      get "/admin/orders"
      expect(response.body).to include("Ekspor CSV")
    end
  end

  describe "bin/rails g wibawa:component" do
    it "copies a component the app can switch to, and the copy renders" do
      Dir.mktmpdir do |dir|
        Wibawa::Generators::ComponentGenerator.start(%w[index_table --quiet], destination_root: dir)
        ruby = File.read(File.join(dir, "app/components/admin/index_table_component.rb"))
        template = File.join(dir, "app/components/admin/index_table_component.html.erb")
        expect(ruby).to include("class IndexTableComponent < Wibawa::IndexTableComponent")
        expect(File.read(template)).to eq(File.read("app/components/wibawa/index_table_component.html.erb"))

        File.write(template, File.read(template).sub("<div ", "<div data-copied "))
        load File.join(dir, "app/components/admin/index_table_component.rb")
        Wibawa.config.components[:index_table] = "Admin::IndexTableComponent"
        get "/admin/orders"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("data-copied", "A-1")
      ensure
        Wibawa.config.components.delete(:index_table)
        Object.send(:remove_const, :Admin) if defined?(Admin)
      end

      expect { Wibawa::Generators::ComponentGenerator.start(%w[nope --quiet], destination_root: Dir.tmpdir) }.to output(/Unknown component/).to_stderr
    end
  end
end
