require "spec_helper"

RSpec.describe "Wibawa saved views", type: :request do
  let!(:customer) { Customer.create!(name: "Sari") }
  let!(:order) { Order.create!(number: "A-1", customer: customer) }
  let(:query) { "q%5Bstatus%5D=pending&search=Sari" }

  before { Wibawa.config.saved_views = true }
  after do
    Wibawa.config.saved_views = false
    Wibawa.config.current_user = :current_user
  end

  it "is off unless configured" do
    Wibawa.config.saved_views = false
    get "/admin/orders"
    expect(response.body).not_to include("data-wb-saved-views")
    post "/admin/orders/views", params: { name: "Mine", query: query }
    expect(response).to have_http_status(:not_found)
  end

  it "saves the current filters under a name and offers them again" do
    get "/admin/orders?search=Sari&q[status]=pending&page=2"
    expect(response.body).to include("data-wb-saved-views", %(value="#{CGI.escapeHTML(query)}"))

    post "/admin/orders/views", params: { name: "Pending Sari", query: "#{query}&page=2&evil=1" }
    expect(response).to redirect_to("/admin/orders?#{query}")
    expect(Wibawa::SavedView.last).to have_attributes(resource_key: "orders", name: "Pending Sari", query: query, owner: nil)

    get "/admin/orders?#{query}"
    expect(response.body).to include(%(href="/admin/orders?#{CGI.escapeHTML(query)}"), 'aria-current="true"')

    post "/admin/orders/views", params: { name: "", query: query }
    expect(Wibawa::SavedView.count).to eq(1)
  end

  it "keeps each user's views to themselves" do
    stub_const("AdminUser", Struct.new(:id, :name))
    viewer = AdminUser.new(1, "Sari")
    Wibawa.config.current_user = -> { viewer }
    theirs = Wibawa::SavedView.create!(resource_key: "orders", name: "Theirs", query: query, owner: "AdminUser:2")
    mine = Wibawa::SavedView.create!(resource_key: "orders", name: "Mine", query: query, owner: Wibawa::SavedView.owner_key(viewer))

    get "/admin/orders"
    expect(response.body).to include(">Mine<")
    expect(response.body).not_to include(">Theirs<")

    delete "/admin/orders/views/#{theirs.id}"
    expect(response).to have_http_status(:not_found)
    delete "/admin/orders/views/#{mine.id}"
    expect(Wibawa::SavedView.pluck(:name)).to eq([ "Theirs" ])
  end
end
