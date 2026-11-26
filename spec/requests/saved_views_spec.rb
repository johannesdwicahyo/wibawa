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

    # The default page size is not part of a view; another size is.
    post "/admin/orders/views", params: { name: "Default size", query: "#{query}&per_page=50" }
    post "/admin/orders/views", params: { name: "Big pages", query: "#{query}&per_page=100" }
    expect(Wibawa::SavedView.order(:id).last(2).map(&:query)).to eq([ query, "per_page=100&#{query}" ])
    get "/admin/orders?#{query}&per_page=50"
    expect(response.body).to include('aria-current="true"')
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

  context "with a signed-in user" do
    let(:viewer) { AdminUser.new(1, "Sari") }
    let!(:mine) { Wibawa::SavedView.create!(resource_key: "orders", name: "Mine", query: query, owner: "AdminUser:1") }
    let!(:theirs) { Wibawa::SavedView.create!(resource_key: "orders", name: "Theirs", query: "search=Budi", owner: "AdminUser:2", shared: true) }

    before do
      stub_const("AdminUser", Struct.new(:id, :name))
      user = viewer
      Wibawa.config.current_user = -> { user }
    end

    it "shows a shared view to everyone, and lets only its owner change it" do
      get "/admin/orders"
      expect(response.body).to include(">Theirs<", ">Shared<", "Edit view Mine")
      expect(response.body).not_to include("Edit view Theirs")

      patch "/admin/orders/views/#{theirs.id}", params: { name: "Taken over" }
      expect(response).to have_http_status(:not_found)
      delete "/admin/orders/views/#{theirs.id}"
      expect(response).to have_http_status(:not_found)
      expect(theirs.reload).to have_attributes(name: "Theirs", shared: true)
    end

    it "renames, shares and unshares a view" do
      patch "/admin/orders/views/#{mine.id}", params: { name: " Pending ", shared: "1", default_view: "0" }
      expect(response).to have_http_status(:see_other)
      expect(mine.reload).to have_attributes(name: "Pending", shared: true, default_view: false, query: query)

      patch "/admin/orders/views/#{mine.id}", params: { name: "", shared: "1" } # a name is required
      expect(mine.reload.name).to eq("Pending")

      patch "/admin/orders/views/#{mine.id}", params: { name: "Pending", shared: "0" }
      expect(mine.reload.shared).to be(false)
    end

    it "opens the index on the default view, one per user, and still lets them leave it" do
      other = Wibawa::SavedView.create!(resource_key: "orders", name: "Other", query: "search=A-1", owner: "AdminUser:1", default_view: true)
      patch "/admin/orders/views/#{mine.id}", params: { name: "Mine", default_view: "1" }
      expect(other.reload.default_view).to be(false) # the newer choice wins
      theirs.update!(default_view: true) # someone else's default, even shared, is not mine

      get "/admin/orders"
      expect(response).to redirect_to("/admin/orders?#{query}")
      follow_redirect!
      expect(response.body).to include(">Default<")

      get "/admin/orders", headers: { "Referer" => "http://www.example.com/admin/orders?#{query}" } # "clear filters"
      expect(response).to have_http_status(:ok)
      get "/admin/orders?search=x"
      expect(response).to have_http_status(:ok)
      get "/admin/orders.csv"
      expect(response).to have_http_status(:ok)
      get "/admin/customers"
      expect(response).to have_http_status(:ok)

      Wibawa.config.saved_views = false
      get "/admin/orders"
      expect(response).to have_http_status(:ok)
    end
  end
end
