require "spec_helper"

# The MCP endpoint as an OAuth resource server: it checks tokens issued
# elsewhere, enforces their scopes, and tells clients where to get one.
RSpec.describe "Wibawa MCP server with OAuth scopes", type: :request do
  let!(:customer) { Customer.create!(name: "Sari") }
  let!(:order) { Order.create!(number: "A-1", customer: customer) }

  # token => what the app's block answers for it
  let(:tokens) do
    { "plain" => :agent, # only a user: unrestricted, as before scopes existed
      "reader" => [ :agent, "wibawa:read" ],
      "orders-reader" => [ :agent, %w[wibawa:read:orders] ],
      "orders-writer" => [ :agent, "wibawa:write:orders openid email" ],
      "writer" => [ :agent, %w[wibawa:write] ],
      "report-reader" => [ :agent, %w[wibawa:read:orders_by_status] ],
      "nothing" => [ :agent, [] ],
      "other-app" => [ :agent, %w[billing:read] ] }
  end

  before do
    known = tokens
    Wibawa.config.mcp_authenticate_with { |token| known[token] }
    Wibawa.config.mcp_authorization_servers = [ "https://auth.example.com" ]
    Wibawa.config.mcp_write = true
  end

  after do
    Wibawa.config.mcp_authenticate_with
    Wibawa.config.mcp_authorization_servers = []
    Wibawa.config.mcp_write = false
    Wibawa.config.mcp_scope_prefix = "wibawa"
    Wibawa.config.mcp_resource = nil
  end

  def rpc(token, method, **params)
    post "/admin/mcp", params: { jsonrpc: "2.0", id: 1, method: method, params: params }.to_json,
                       headers: { "Content-Type" => "application/json", "Authorization" => ("Bearer #{token}" if token) }.compact
    response.parsed_body if response.media_type == "application/json"
  end

  def call(token, tool, arguments = {})
    body = rpc(token, "tools/call", name: tool, arguments: arguments)
    return response.status unless response.status == 200

    result = body.fetch("result")
    result["isError"] ? { "error" => result["content"].first["text"] } : JSON.parse(result["content"].first["text"])
  end

  def tools(token) = rpc(token, "tools/list").dig("result", "tools").map { |tool| tool["name"] }
  def challenge = response.headers["WWW-Authenticate"]

  describe "telling a client where to get a token" do
    it "publishes protected resource metadata, and points at it when it refuses" do
      get "/admin/mcp/oauth-protected-resource"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "resource" => "http://www.example.com/admin/mcp", "authorization_servers" => [ "https://auth.example.com" ],
        "scopes_supported" => [ "wibawa:read" ], "bearer_methods_supported" => [ "header" ], "resource_name" => "Admin"
      )

      rpc(nil, "tools/list")
      expect(response).to have_http_status(:unauthorized)
      expect(challenge).to eq(%(Bearer scope="wibawa:read", resource_metadata="http://www.example.com/admin/mcp/oauth-protected-resource"))
      rpc("expired-or-unknown", "tools/list")
      expect(response).to have_http_status(:unauthorized)
      expect(challenge).to include("resource_metadata=")
    end

    it "uses the configured URL behind a proxy" do
      Wibawa.config.mcp_resource = "https://admin.example.com/ops/mcp/"
      get "/admin/mcp/oauth-protected-resource"
      expect(response.parsed_body["resource"]).to eq("https://admin.example.com/ops/mcp") # no trailing slash
      rpc(nil, "tools/list")
      expect(challenge).to include(%(resource_metadata="https://admin.example.com/ops/mcp/oauth-protected-resource"))
    end

    it "gives the app's block this endpoint's URL, to compare a token's audience with" do
      # A stand-in for a signed token: "audience|scopes". The block refuses one issued for another service.
      Wibawa.config.mcp_authenticate_with do |token|
        audience, scopes = token.split("|")
        [ :agent, scopes ] if audience == mcp_resource
      end
      expect(call("http://www.example.com/admin/mcp|wibawa:read", "list_records", resource: "orders")["records"].size).to eq(1)
      expect(call("https://billing.example.com/api|wibawa:read", "list_records", resource: "orders")).to eq(401)
      expect(challenge).to include("resource_metadata=")
    end

    it "says nothing about OAuth when no authorization server is named" do
      Wibawa.config.mcp_authorization_servers = []
      get "/admin/mcp/oauth-protected-resource"
      expect(response).to have_http_status(:not_found)
      rpc(nil, "tools/list")
      expect(challenge).to eq("Bearer")

      Wibawa.config.mcp_authorization_servers = [ "https://auth.example.com" ]
      Wibawa.config.mcp_authenticate_with # the endpoint itself is off
      get "/admin/mcp/oauth-protected-resource"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "what a token's scopes allow" do
    it "leaves a token with no scope information unrestricted" do
      expect(tools("plain")).to include("list_records", "update_record")
      expect(call("plain", "update_record", resource: "orders", id: order.id, attributes: { number: "A-2" })["number"]).to eq("A-2")
    end

    it "lets a read scope read everything and change nothing" do
      expect(tools("reader")).to include("list_resources", "list_records", "get_record", "run_report")
      expect(tools("reader")).not_to include("create_record", "update_record", "delete_record", "run_action", "run_batch_action")
      expect(call("reader", "list_records", resource: "customers")["records"].size).to eq(1)
      expect(call("reader", "run_report", report: "orders_by_status")["rows"]).to be_present

      expect(call("reader", "update_record", resource: "orders", id: order.id, attributes: { number: "X" })).to eq(403)
      expect(challenge).to eq(%(Bearer error="insufficient_scope", scope="wibawa:write:orders", resource_metadata="http://www.example.com/admin/mcp/oauth-protected-resource"))
      expect(order.reload.number).to eq("A-1")
    end

    it "keeps a scope for one resource to that resource" do
      listed = call("orders-reader", "list_resources")
      expect(listed.map { |resource| resource["resource"] }).to eq(%w[orders])
      expect(listed.first).not_to have_key("writable_attributes") # it may not write orders either
      expect(call("orders-reader", "get_record", resource: "orders", id: order.id)["number"]).to eq("A-1")

      expect(call("orders-reader", "list_records", resource: "customers")).to eq(403)
      expect(challenge).to include(%(error="insufficient_scope"), %(scope="wibawa:read:customers"))
      expect(call("orders-reader", "run_report", report: "orders_by_status")).to eq(403)
      expect(call("orders-reader", "list_reports")).to eq([])
    end

    it "lets a write scope for one resource read and change it, and nothing else" do
      expect(tools("orders-writer")).to include("update_record")
      expect(call("orders-writer", "list_resources").first).to include("resource" => "orders", "writable_attributes" => be_present)
      expect(call("orders-writer", "update_record", resource: "orders", id: order.id, attributes: { number: "A-9" })["number"]).to eq("A-9")
      expect(call("orders-writer", "get_record", resource: "orders", id: order.id)["number"]).to eq("A-9") # write implies read

      expect(call("orders-writer", "update_record", resource: "customers", id: customer.id, attributes: { name: "X" })).to eq(403)
      expect(challenge).to include(%(scope="wibawa:write:customers"))
      expect(customer.reload.name).to eq("Sari")
    end

    it "lets an unqualified write scope do everything" do
      expect(call("writer", "update_record", resource: "customers", id: customer.id, attributes: { name: "Sari Dewi" })["name"]).to eq("Sari Dewi")
      expect(call("writer", "run_report", report: "orders_by_status")["rows"]).to be_present
    end

    it "takes a report's key as a scope too" do
      expect(call("report-reader", "list_reports").map { |report| report["report"] }).to eq(%w[orders_by_status])
      expect(call("report-reader", "run_report", report: "orders_by_status")["rows"]).to be_present
      expect(call("report-reader", "run_report", report: "orders_per_customer")).to eq(403)
      expect(call("report-reader", "list_resources")).to eq([])
    end

    it "refuses a token with no scope of its own, whatever else it carries" do
      %w[nothing other-app].each do |token|
        expect(call(token, "list_resources")).to eq(403)
        expect(challenge).to include(%(scope="wibawa:read"))
        expect(tools(token)).not_to include("update_record")
      end
    end

    it "still applies the user's own authorization inside a scope" do
      Wibawa.config.authorization = ->(_user, action, _subject) { action != :update }
      expect(call("writer", "update_record", resource: "orders", id: order.id, attributes: { number: "X" })).to eq("error" => "Not authorized.")
    end

    it "does not need write to be switched on to read, and scopes cannot switch it on" do
      Wibawa.config.mcp_write = false
      expect(tools("writer")).not_to include("update_record")
      expect(call("writer", "list_records", resource: "orders")["records"].size).to eq(1)
    end

    it "takes another prefix" do
      Wibawa.config.mcp_scope_prefix = "ops"
      tokens["ops"] = [ :agent, "ops:read:orders" ]
      expect(call("ops", "get_record", resource: "orders", id: order.id)["number"]).to eq("A-1")
      expect(call("reader", "list_resources")).to eq(403) # "wibawa:read" means nothing now
      expect(challenge).to include(%(scope="ops:read"))
    end
  end

  describe Wibawa::McpScopes do
    it "knows the hierarchy: write covers read, and no key covers every key" do
      scopes = described_class.new("wibawa:read:orders wibawa:write:customers")
      expect(scopes.allow?("orders")).to be(true)
      expect(scopes.allow?("orders", write: true)).to be(false)
      expect(scopes.allow?("customers")).to be(true)
      expect(scopes.allow?("customers", write: true)).to be(true)
      expect(scopes.allow?("products")).to be(false)
      expect(scopes.allow?).to be(true) # something
      expect(scopes.allow?(write: true)).to be(true)
      expect(scopes.needed("products", write: true)).to eq("wibawa:write:products")

      expect(described_class.new(nil)).to be_unrestricted
      expect(described_class.new([]).allow?).to be(false)
      expect(described_class.new(%w[wibawa:admin wibawa wibawa:read: wibawa:write:]).allow?).to be(false) # unknown or malformed: nothing
      expect(described_class.new("wibawa:read").allow?("anything")).to be(true)
    end
  end
end
