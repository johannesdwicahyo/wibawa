require "spec_helper"

RSpec.describe "Wibawa audit log", type: :request do
  let!(:customer) { Customer.create!(name: "Sari") }
  let!(:order) { Order.create!(number: "A-1", customer: customer) }
  let(:entries) { Wibawa::AuditEntry.order(:id) }

  def switch(on)
    Wibawa.config.audit_log = on
    Wibawa.load!
  end

  before { switch(true) }
  after do
    switch(false)
    Wibawa.config.current_user = :current_user
    Wibawa.config.mcp_authenticate_with
    Wibawa.config.mcp_write = false
  end

  it "records nothing and has no page when it is off" do
    switch(false)
    patch "/admin/orders/#{order.id}", params: { record: { number: "A-9" } }
    expect(Wibawa::AuditEntry.count).to eq(0)
    get "/admin/audit_log"
    expect(response).to have_http_status(:not_found)
  end

  it "records creates, updates with their changes, actions and deletes" do
    stub_const("AdminUser", Struct.new(:id, :name))
    admin = AdminUser.new(7, "Budi")
    Wibawa.config.current_user = -> { admin }

    post "/admin/orders", params: { record: { number: "B-2", customer_id: customer.id } }
    patch "/admin/orders/#{order.id}", params: { record: { number: "A-9" } }
    patch "/admin/orders/#{order.id}", params: { record: { number: "" } } # invalid: nothing happened
    post "/admin/orders/#{order.id}/actions/pay"
    post "/admin/orders/batch", params: { batch_action: "destroy", ids: [ order.id ] }
    delete "/admin/orders/#{Order.find_by!(number: 'B-2').id}"

    expect(entries.pluck(:action)).to eq(%w[create update pay batch_destroy destroy])
    expect(entries.pluck(:via, :actor, :actor_label).uniq).to eq([ [ "web", "AdminUser:7", "Budi" ] ])
    expect(entries.second).to have_attributes(resource_key: "orders", record_id: order.id.to_s, record_label: "A-9",
                                              data: { "number" => %w[A-1 A-9] })
    expect(entries.fourth.data).to eq("ids" => [ order.id.to_s ], "count" => 1)
  end

  it "masks secrets and cannot be edited" do
    expect(Wibawa::AuditEntry.filter("password_digest" => %w[a b], "name" => %w[x y], "updated_at" => [ 1, 2 ]))
      .to eq("password_digest" => "[FILTERED]", "name" => %w[x y])

    entry = Wibawa::AuditEntry.record!(user: nil, action: :update, resource: Wibawa.registry["orders"], via: "web", record: order)
    expect { entry.update!(action: "nothing") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    patch "/admin/audit_log/#{entry.id}", params: { record: { action: "nothing" } }
    expect(response).to have_http_status(:not_found)
  end

  it "shows the log, filtered to one record from its History button" do
    patch "/admin/orders/#{order.id}", params: { record: { number: "A-9" } }
    patch "/admin/customers/#{customer.id}", params: { record: { name: "Sari W" } }

    get "/admin/orders/#{order.id}"
    history = "/admin/audit_log?q%5Brecord_id%5D=#{order.id}&q%5Bresource_key%5D=orders"
    expect(response.body).to include(%(href="#{CGI.escapeHTML(history)}"))

    get history
    expect(response.body).to include(">A-9<")
    expect(response.body).not_to include(">Sari W<")

    get "/admin/audit_log/#{entries.first.id}"
    expect(response.body).to include("A-1", "A-9")
  end

  it "records what an agent does through the MCP server" do
    Wibawa.config.mcp_authenticate_with { |token| token == "secret" ? :agent : nil }
    Wibawa.config.mcp_write = true
    post "/admin/mcp", headers: { "Content-Type" => "application/json", "Authorization" => "Bearer secret" },
                       params: { jsonrpc: "2.0", id: 1, method: "tools/call",
                                 params: { name: "update_record", arguments: { resource: "orders", id: order.id, attributes: { number: "M-1" } } } }.to_json

    expect(entries.last).to have_attributes(action: "update", via: "mcp", actor_label: "agent", data: { "number" => %w[A-1 M-1] })
  end
end
