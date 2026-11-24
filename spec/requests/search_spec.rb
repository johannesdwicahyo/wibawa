require "spec_helper"

RSpec.describe "Wibawa command palette", type: :request do
  let!(:customer) { Customer.create!(name: "Sari") }
  let!(:order) { Order.create!(number: "A-1", customer: customer) }

  it "puts every page and new-record shortcut in the layout" do
    get "/admin"
    palette = response.body[/<dialog data-wb-palette.*?<\/dialog>/m]
    expect(palette).to include('href="/admin/orders"', 'href="/admin/orders/new"', 'href="/admin/reports/orders_by_status"', 'data-search-url="/admin/-/search"')
  end

  it "finds records across searchable resources" do
    get "/admin/-/search", params: { q: "sari" }
    expect(response.body).to include(%(href="/admin/orders/#{order.id}"), "A-1")
    expect(response.body).not_to include("<html")

    get "/admin/-/search", params: { q: "s" }
    expect(response.body.strip).to be_empty
  end

  it "leaves out what the user may not see" do
    Wibawa.config.authorize_with { |_user, _action, subject| subject != Order && !subject.is_a?(Order) }
    get "/admin/-/search", params: { q: "sari" }
    expect(response.body).not_to include("/admin/orders/")
  end

  it "honours each resource's scoped_collection override" do
    resource = Wibawa.registry["orders"]
    resource.controller { def scoped_collection = super.where.not(number: "A-1") }
    get "/admin/-/search", params: { q: "sari" }
    expect(response.body).not_to include("/admin/orders/")
  ensure
    resource.controller_blocks.pop
  end
end
