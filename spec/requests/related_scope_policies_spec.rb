require "spec_helper"
require "pundit"
require "action_policy"

# spec/requests/related_scope_spec.rb proves the behaviour with a small adapter
# written for the purpose. This runs the same ground through the two policy
# libraries people use, with scope classes written the way their docs show.
RSpec.describe "Wibawa and related records, with real policies", type: :request do
  let!(:sari) { Customer.create!(name: "Sari") }
  let!(:hidden) { Customer.create!(name: "Rahasia") }
  let!(:open_order) { Order.create!(number: "A-1", customer: sari, line_items: [ LineItem.new(product: "Batik") ]) }
  let!(:mixed_order) { Order.create!(number: "H-1", customer: hidden, line_items: [ LineItem.new(product: "Secret") ]) }
  let!(:secret_order) { Order.create!(number: "X-9", customer: sari) }

  def queries
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" || payload[:sql].match?(/\A(BEGIN|COMMIT|SAVEPOINT|RELEASE)/) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end

  def csv_numbers(query = {})
    get "/admin/orders.csv", params: { q: query }
    response.body.lines.drop(1).map { |line| line.split(",")[1] }.sort
  end

  # The rules, the same for both libraries: nobody sees a customer named
  # "Rahasia", an order numbered "X-...", or a line item whose product is "Secret".
  shared_examples "related records under a policy scope" do
    it "masks a related record outside the scope, in a cell, on the record's page and in CSV" do
      get "/admin/orders"
      expect(response.body).to include("A-1", "Sari", "H-1", "##{hidden.id}")
      expect(response.body).not_to include("Rahasia", "X-9") # the hidden customer's name, and the order outside its own scope

      get "/admin/orders/#{mixed_order.id}"
      expect(response.body).to include("##{hidden.id}")
      expect(response.body).not_to include("Rahasia")

      get "/admin/orders.csv"
      expect(response.body).to include("H-1", "##{hidden.id}")
      expect(response.body).not_to include("Rahasia")
    end

    it "lists only the has_many records in scope, through the association itself" do
      Wibawa.resource(Customer) do
        index { column :name and column :orders }
        show { attributes :name and table_for :orders }
      end
      get "/admin/customers"
      expect(response.body).to include("A-1")
      expect(response.body).not_to include("X-9", "Rahasia")
      get "/admin/customers/#{sari.id}"
      expect(response.body).to include("A-1")
      expect(response.body).not_to include("X-9")
    ensure
      Wibawa.load!
    end

    it "refuses a newly chosen related record outside the scope, and leaves an existing one alone" do
      expect { post "/admin/orders", params: { record: { number: "N-1", customer_id: hidden.id } } }.not_to change(Order, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to match(/id="record_customer_id_error"[^>]*>Is not one you can choose</)

      patch "/admin/orders/#{open_order.id}", params: { record: { customer_id: hidden.id } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(open_order.reload.customer).to eq(sari)

      patch "/admin/orders/#{mixed_order.id}", params: { record: { number: "H-2", customer_id: hidden.id } }
      expect(response).to have_http_status(:see_other)
      expect(mixed_order.reload.number).to eq("H-2")

      elsewhere = Order.create!(number: "X-8", customer: hidden)
      patch "/admin/customers/#{sari.id}", params: { record: { name: "Sari", order_ids: [ open_order.id, secret_order.id, elsewhere.id ] } }
      expect(response).to have_http_status(:unprocessable_entity) # an order outside the Order scope cannot be attached
      expect(elsewhere.reload.customer).to eq(hidden)

      patch "/admin/customers/#{sari.id}", params: { record: { name: "Sari", order_ids: [ open_order.id, secret_order.id ] } }
      expect(response).to have_http_status(:see_other) # X-9 is outside the scope too, but Sari already had it
    end

    it "does not match a filter through associated records outside the scope" do
      expect(csv_numbers("line_items.product" => "Batik")).to eq([ "A-1" ])
      expect(csv_numbers("line_items.product" => "Secret")).to eq([])
      expect(csv_numbers(line_items: mixed_order.line_items.first.id)).to eq([])
      expect(csv_numbers(customer: hidden.id)).to eq([ "H-1" ]) # a belongs_to filter only narrows what is already listed
    end

    it "asks once per association for a page, however many rows it has" do
      get "/admin/orders" # warm up
      few = queries { get "/admin/orders" }
      25.times { |n| Order.create!(number: "B-#{n}", customer: Customer.create!(name: "C#{n}")) }
      many = queries { get "/admin/orders" }
      expect(many).to eq(few)
    end

    it "treats a model that has no policy as having nothing to hide" do
      stub_const("Ghost", Class.new(ActiveRecord::Base) { self.table_name = "customers" })
      related = Wibawa::RelatedScope.new(Wibawa::Authorization.build(nil))
      expect(related.restricted?(Ghost)).to be(false)
      expect(related.visible?(Ghost.find(hidden.id))).to be(true)
      expect(related.restricted?(Customer)).to be(true)
      expect(related.visible?(hidden)).to be(false)
      expect(related.visible?(sari)).to be(true)
    end
  end

  describe "Pundit" do
    before do
      stub_const("ApplicationPolicy", Class.new do
        attr_reader :user, :record

        def initialize(user, record) = (@user, @record = user, record)
        %i[index? show? create? update? destroy?].each { |rule| define_method(rule) { true } }
      end)
      # As Pundit's generator writes it: a Scope class inside the policy, with `resolve`.
      stub_const("ApplicationPolicy::Scope", Class.new do
        attr_reader :user, :scope

        def initialize(user, scope) = (@user, @scope = user, scope)
        def resolve = scope.all
      end)
      stub_const("CustomerPolicy", Class.new(ApplicationPolicy))
      stub_const("CustomerPolicy::Scope", Class.new(ApplicationPolicy::Scope) { def resolve = scope.where.not(name: "Rahasia") })
      stub_const("OrderPolicy", Class.new(ApplicationPolicy))
      stub_const("OrderPolicy::Scope", Class.new(ApplicationPolicy::Scope) { def resolve = scope.where.not(Order.arel_table[:number].matches("X-%")) })
      stub_const("LineItemPolicy", Class.new(ApplicationPolicy))
      stub_const("LineItemPolicy::Scope", Class.new(ApplicationPolicy::Scope) { def resolve = scope.where.not(product: "Secret") })
      stub_const("ProductPolicy", Class.new(ApplicationPolicy))
      stub_const("ProductPolicy::Scope", Class.new(ApplicationPolicy::Scope))
      stub_const("Wibawa::ReportPolicy", Class.new(ApplicationPolicy))
      stub_const("Wibawa::PagePolicy", Class.new(ApplicationPolicy))
      Wibawa.config.authorization = :pundit
    end

    it_behaves_like "related records under a policy scope"
  end

  describe "ActionPolicy" do
    before do
      stub_const("ApplicationPolicy", Class.new(ActionPolicy::Base) do
        authorize :user, allow_nil: true
        %i[index? show? create? update? destroy?].each { |rule| define_method(rule) { true } }
        scope_for(:active_record_relation) { |relation| relation }
      end)
      # scope_for(:active_record_relation) is what ActionPolicy's `relation_scope` stands for; the short
      # form needs its Rails integration loaded at boot, which this one-file test app does not do.
      stub_const("CustomerPolicy", Class.new(ApplicationPolicy) { scope_for(:active_record_relation) { |relation| relation.where.not(name: "Rahasia") } })
      stub_const("OrderPolicy", Class.new(ApplicationPolicy) { scope_for(:active_record_relation) { |relation| relation.where.not(Order.arel_table[:number].matches("X-%")) } })
      stub_const("LineItemPolicy", Class.new(ApplicationPolicy) { scope_for(:active_record_relation) { |relation| relation.where.not(product: "Secret") } })
      stub_const("ProductPolicy", Class.new(ApplicationPolicy))
      stub_const("Wibawa::ReportPolicy", Class.new(ApplicationPolicy))
      stub_const("Wibawa::PagePolicy", Class.new(ApplicationPolicy))
      Wibawa.config.authorization = :action_policy
    end

    it_behaves_like "related records under a policy scope"
  end
end
