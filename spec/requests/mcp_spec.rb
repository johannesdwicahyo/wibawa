require "spec_helper"

RSpec.describe "Wibawa MCP server", type: :request do
  let!(:customer) { Customer.create!(name: "Sari") }
  let!(:order) { Order.create!(number: "A-1", customer: customer) }
  let(:user) { Struct.new(:admin).new(true) }

  # The block runs inside the controller, so it cannot see `let` values.
  before do
    admin = user
    Wibawa.config.mcp_authenticate_with { |token| token == "secret" ? admin : nil }
  end
  after do
    Wibawa.config.mcp_authenticate_with
    Wibawa.config.mcp_write = false
  end

  def rpc(method, token: "secret", **params)
    post "/admin/mcp", params: { jsonrpc: "2.0", id: 1, method: method, params: params }.to_json,
                       headers: { "Content-Type" => "application/json", "Authorization" => ("Bearer #{token}" if token) }.compact
    response.parsed_body if response.media_type == "application/json"
  end

  # The tool's JSON result, or its error text when the call failed.
  def call(tool, arguments = {})
    result = rpc("tools/call", name: tool, arguments: arguments).fetch("result")
    text = result["content"].first["text"]
    result["isError"] ? { "error" => text } : JSON.parse(text)
  end

  it "is switched off until authentication is configured" do
    Wibawa.config.mcp_authenticate_with
    rpc("tools/list")
    expect(response).to have_http_status(:not_found)
  end

  it "rejects a missing or wrong token, and anything but POST" do
    rpc("tools/list", token: nil)
    expect(response).to have_http_status(:unauthorized)
    rpc("tools/list", token: "nope")
    expect(response).to have_http_status(:unauthorized)

    get "/admin/mcp", headers: { "Authorization" => "Bearer secret" }
    expect(response).to have_http_status(:method_not_allowed)
  end

  it "offers only read tools by default" do
    expect(rpc("initialize", protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "spec", version: "1" }).dig("result", "serverInfo", "name")).to eq("wibawa")
    expect(rpc("tools/list").dig("result", "tools").map { |t| t["name"] }).to eq(%w[list_resources list_records get_record list_reports run_report])

    expect(rpc("tools/call", name: "delete_record", arguments: { resource: "orders", id: order.id })).not_to include("result" => hash_including("isError" => false))
    expect(Order.exists?(order.id)).to be(true)
  end

  it "lists resources and records, with scopes, search and filters" do
    Order.create!(number: "B-2", customer: customer, status: :paid)

    expect(call("list_resources").map { |r| r["resource"] }).to include("orders", "customers")

    found = call("list_records", resource: "orders", search: "Sari", filters: { status: "paid" })
    expect(found["records"].map { |r| r["number"] }).to eq(["B-2"])
    expect(found["total"]).to eq(1)

    expect(call("list_records", resource: "orders", scope: "pending")["records"].map { |r| r["number"] }).to eq(["A-1"])
    expect(call("get_record", resource: "orders", id: order.id)).to include("number" => "A-1", "customer" => { "id" => customer.id, "name" => "Sari" })
    expect(call("get_record", resource: "orders", id: 0)).to eq("error" => "Not found.")
  end

  it "lists and runs reports, binding their parameters" do
    Order.create!(number: "B-2", customer: customer, total: 15)
    order.update!(total: 10)

    listed = call("list_reports").find { |r| r["report"] == "orders_by_status" }
    expect(listed).to include("title" => "Orders by status", "params" => [{ "name" => "number", "type" => "string", "default" => "%" }])

    all = call("run_report", report: "orders_by_status")
    expect(all).to include("total" => 1, "truncated" => false, "params" => { "number" => "%" })
    expect(all["rows"].first).to include("orders" => 2)

    expect(call("run_report", report: "orders_by_status", params: { number: "B-%" })["rows"].first).to include("orders" => 1)
    expect(call("run_report", report: "orders_by_status", params: { number: "x' OR '1'='1" })["rows"]).to eq([])
    expect(call("run_report", report: "nope")).to eq("error" => "Not found.")

    Wibawa.config.authorize_with { |_user, _action, subject| !subject.is_a?(Wibawa::Report) }
    expect(call("list_reports")).to eq([])
    expect(call("run_report", report: "orders_by_status")).to eq("error" => "Not authorized.")
  end

  it "applies the same authorization as the browser" do
    Wibawa.config.authorize_with { |_user, _action, subject| subject != Order && !subject.is_a?(Order) }

    expect(call("list_resources").map { |r| r["resource"] }).not_to include("orders")
    expect(call("list_records", resource: "orders")).to eq("error" => "Not authorized.")
    expect(call("get_record", resource: "orders", id: order.id)).to eq("error" => "Not authorized.")
  end

  it "honours a resource's scoped_collection override" do
    Order.create!(number: "B-2", customer: customer)
    resource = Wibawa.registry["orders"]
    resource.controller { def scoped_collection = super.where(number: "B-2") }

    expect(call("list_records", resource: "orders")["records"].map { |r| r["number"] }).to eq(["B-2"])
    expect(call("get_record", resource: "orders", id: order.id)).to eq("error" => "Not found.")
  ensure
    resource.controller_blocks.pop
  end

  it "writes through strong params and runs member actions when writing is on" do
    Wibawa.config.mcp_write = true

    created = call("create_record", resource: "orders", attributes: { number: "C-3", customer_id: customer.id, total: 99 })
    expect(Order.find(created["id"])).to have_attributes(number: "C-3", total: nil)

    expect(call("update_record", resource: "orders", id: order.id, attributes: { number: "" })["error"]).to include("Number")
    expect(call("run_action", resource: "orders", id: order.id, action: "pay")["message"]).to eq("Pay done.")
    expect(order.reload).to be_paid

    expect(call("delete_record", resource: "orders", id: order.id)).to eq("deleted" => order.id)
  end
end
