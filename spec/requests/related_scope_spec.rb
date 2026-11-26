require "spec_helper"
require "tmpdir"

# A user who may see a record is not thereby allowed to see, choose or filter
# through everything it points at.
RSpec.describe "Wibawa and records reached from other records", type: :request do
  # Everyone sees every order; nobody sees a customer named "Rahasia", an
  # order numbered "X-...", or a line item whose product is "Secret".
  let(:adapter) do
    Class.new(Wibawa::Authorization::Allow) do
      def scope(relation)
        case relation.klass.name
        when "Customer" then relation.where.not(name: "Rahasia")
        when "LineItem" then relation.where.not(product: "Secret")
        when "Order" then relation.where.not(Order.arel_table[:number].matches("X-%"))
        else relation
        end
      end
    end
  end

  let!(:sari) { Customer.create!(name: "Sari") }
  let!(:hidden) { Customer.create!(name: "Rahasia") }
  let!(:open_order) { Order.create!(number: "A-1", customer: sari, line_items: [ LineItem.new(product: "Batik") ]) }
  let!(:mixed_order) { Order.create!(number: "H-1", customer: hidden, line_items: [ LineItem.new(product: "Secret") ]) }

  before { Wibawa.config.authorization = adapter }
  after do
    Wibawa.config.authorization = nil
    Wibawa.config.mcp_authenticate_with
    Wibawa.config.mcp_write = false
  end

  def queries
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" || payload[:sql].match?(/\A(BEGIN|COMMIT|SAVEPOINT|RELEASE)/) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end

  def mcp(tool, arguments)
    post "/admin/mcp", headers: { "Content-Type" => "application/json", "Authorization" => "Bearer secret" },
                       params: { jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: tool, arguments: arguments } }.to_json
    result = response.parsed_body.fetch("result")
    text = result["content"].first["text"]
    result["isError"] ? { "error" => text } : JSON.parse(text)
  end

  describe "showing" do
    it "names a related record only when the user may see it, everywhere" do
      get "/admin/orders"
      expect(response.body).to include("Sari", "##{hidden.id}")
      expect(response.body).not_to include("Rahasia")

      get "/admin/orders/#{mixed_order.id}"
      expect(response.body).to include("H-1", "##{hidden.id}")
      expect(response.body).not_to include("Rahasia")

      get "/admin/orders.csv"
      expect(response.body).to include("A-1", "Sari", "H-1", "##{hidden.id}")
      expect(response.body).not_to include("Rahasia")

      Wibawa.config.mcp_authenticate_with { |token| token == "secret" ? :agent : nil }
      listed = mcp("list_records", resource: "orders")["records"].to_h { |record| [ record["number"], record["customer"] ] }
      expect(listed).to eq("A-1" => { "id" => sari.id, "name" => "Sari" }, "H-1" => { "id" => hidden.id, "name" => "##{hidden.id}" })
      expect(mcp("get_record", resource: "orders", id: mixed_order.id).to_json).not_to include("Rahasia")
    end

    it "lists only the associated records the user may see, in a cell and on the record's page" do
      Order.create!(number: "X-9", customer: sari)
      Wibawa.resource Customer do
        index { column :name and column :orders }
        show { attributes :name and table_for :orders }
      end
      get "/admin/customers"
      expect(response.body).to include("A-1")
      expect(response.body).not_to include("X-9")
      get "/admin/customers/#{sari.id}"
      expect(response.body).to include("A-1")
      expect(response.body).not_to include("X-9")
    ensure
      Wibawa.load!
    end

    it "asks once per association for a page, not once per row, and not at all without authorization" do
      20.times { |n| Order.create!(number: "B-#{n}", customer: Customer.create!(name: "C#{n}")) }
      get "/admin/orders" # warm up
      scoped = queries { get "/admin/orders" }

      Wibawa.config.authorization = nil
      plain = queries { get "/admin/orders" }
      expect(response.body).to include("Rahasia") # nothing to hide when nothing is restricted
      expect(scoped - plain).to be_between(1, 3) # the customers of the page in one query, plus the filter's choices being scoped
    end
  end

  describe "saving" do
    it "refuses a newly chosen related record outside the user's scope, from a form" do
      expect { post "/admin/orders", params: { record: { number: "N-1", customer_id: hidden.id } } }.not_to change(Order, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to match(/id="record_customer_id_error"[^>]*>Is not one you can choose</) # under the field it belongs to

      patch "/admin/orders/#{open_order.id}", params: { record: { number: "A-1b", customer_id: hidden.id } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(open_order.reload).to have_attributes(number: "A-1", customer: sari) # nothing was saved, the number neither

      patch "/admin/orders/#{open_order.id}", params: { record: { number: "", customer_id: hidden.id } }
      expect(response.body).to include('id="record_customer_id_error"', 'id="record_number_error"') # beside the model's own errors
    end

    it "leaves alone a value the record already had" do
      patch "/admin/orders/#{mixed_order.id}", params: { record: { number: "H-2", customer_id: hidden.id } }
      expect(response).to have_http_status(:see_other)
      expect(mixed_order.reload).to have_attributes(number: "H-2", customer: hidden)
    end

    it "refuses has_many ids outside the scope before any of them is written" do
      secret_order = Order.create!(number: "X-1", customer: hidden)
      patch "/admin/customers/#{sari.id}", params: { record: { name: "Sari", order_ids: [ open_order.id, secret_order.id ] } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to match(/id="record_order_ids_error"[^>]*>Is not one you can choose</)
      expect(secret_order.reload.customer).to eq(hidden) # assigning ids writes at once, so it must not happen at all

      patch "/admin/customers/#{sari.id}", params: { record: { name: "Sari", order_ids: [ open_order.id, mixed_order.id ] } }
      expect(response).to have_http_status(:see_other)
      expect(mixed_order.reload.customer).to eq(sari) # an order the user may see can be moved
    end

    it "refuses it from an agent and from a CSV import too" do
      Wibawa.config.mcp_authenticate_with { |token| token == "secret" ? :agent : nil }
      Wibawa.config.mcp_write = true
      expect(mcp("create_record", resource: "orders", attributes: { number: "M-1", customer_id: hidden.id })).to eq("error" => "Customer is not one you can choose")
      expect(mcp("update_record", resource: "orders", id: open_order.id, attributes: { customer_id: hidden.id })).to eq("error" => "Customer is not one you can choose")
      expect(mcp("create_record", resource: "orders", attributes: { number: "M-2", customer_id: sari.id })["number"]).to eq("M-2")

      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "o.csv"), "number,customer_id\nI-1,#{sari.id}\nI-2,#{hidden.id}\n")
        post "/admin/orders/import", params: { file: Rack::Test::UploadedFile.new(File.join(dir, "o.csv"), "text/csv") }
      end
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Line 3:", "Customer is not one you can choose")
      expect(Order.where(number: %w[I-1 I-2])).to be_empty
    end

    it "judges each row of nested attributes as its own record" do
      related = Wibawa::RelatedScope.new(adapter.new(nil))
      secret_order = Order.create!(number: "X-2", customer: sari)
      expect(related.outside(sari, "orders_attributes" => [ { "number" => "N-9", "customer_id" => hidden.id } ])).to eq("orders_attributes" => :orders)
      expect(related.outside(sari, "orders_attributes" => { "0" => { "id" => open_order.id, "number" => "A-1c" } })).to eq({})
      expect(related.outside(LineItem.new, order_id: secret_order.id)).to eq("order_id" => :order)
      expect(related.outside(LineItem.new, order_id: open_order.id, product: "x")).to eq({})
    end
  end

  describe "filtering" do
    def numbers(query)
      get "/admin/orders.csv", params: { q: query }
      response.body.lines.drop(1).map { |line| line.split(",")[1] }.sort
    end

    it "does not match through associated records the user may not see" do
      expect(numbers("line_items.product" => "Batik")).to eq([ "A-1" ])
      expect(numbers("line_items.product" => "Secret")).to eq([])               # the order is visible, its line item is not
      expect(numbers(line_items: mixed_order.line_items.first.id)).to eq([])
      expect(numbers(line_items: open_order.line_items.first.id)).to eq([ "A-1" ])
      expect(numbers(customer: hidden.id)).to eq([ "H-1" ])                     # a belongs_to filter only narrows what is already shown

      Wibawa.config.authorization = nil
      expect(numbers("line_items.product" => "Secret")).to eq([ "H-1" ])
    end
  end

  it "treats a model with no policy as unrestricted, and lets other errors through" do
    stub_const("NotDefinedError", Class.new(StandardError))
    lax = Class.new(Wibawa::Authorization::Allow) { def scope(_relation) = raise(NotDefinedError, "no policy for Customer") }
    expect(Wibawa::RelatedScope.new(lax.new(nil)).visible?(hidden)).to be(true)

    broken = Class.new(Wibawa::Authorization::Allow) { def scope(_relation) = raise(ArgumentError, "a bug in the policy") }
    expect { Wibawa::RelatedScope.new(broken.new(nil)).visible?(hidden) }.to raise_error(ArgumentError)
  end
end
