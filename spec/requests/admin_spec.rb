require "spec_helper"

RSpec.describe "Wibawa admin", type: :request do
  let!(:customer) { Customer.create!(name: "Sari") }
  let!(:order) { Order.create!(number: "A-1", customer: customer, line_items: [ LineItem.new(product: "Batik") ]) }

  it "renders every read page" do
    [ "/admin", "/admin/orders", "/admin/orders?scope=pending&search=Sari&q[status]=pending&sort=number",
     "/admin/orders/#{order.id}", "/admin/customers", "/admin/line_items" ].each do |path|
      get path
      expect(response).to have_http_status(:ok), "#{path} returned #{response.status}"
    end
  end

it "shows active filters as chips that remove one filter and keep the rest" do
    get "/admin/orders?search=Sari&q[status]=pending"
    expect(response.body).to include("<details data-wb-filters", "Remove filter: Status", ">Pending<")
    expect(response.body).to include('href="/admin/orders?search=Sari"')

    get "/admin/orders"
    expect(response.body).not_to include("Remove filter")
  end

  # Regression: the nested builder used the component as its template, so
  # f.label hit NestedFieldsComponent#label and every form page raised.
  it "renders new and edit forms, including nested fields" do
    get "/admin/orders/new"
    expect(response).to have_http_status(:ok)

    get "/admin/orders/#{order.id}/edit"
    expect(response.body).to include("record[line_items_attributes][0][product]", "Batik")

    get "/admin/customers/new"
    expect(response).to have_http_status(:ok)
  end

  it "creates a record with nested rows and rejects invalid ones" do
    post "/admin/orders", params: { record: { number: "B-2", customer_id: customer.id,
                                              line_items_attributes: { "0" => { product: "Kain", position: 1 } } } }
    created = Order.find_by!(number: "B-2")
    expect(response).to redirect_to("/admin/orders/#{created.id}")
    expect(created.line_items.pluck(:product)).to eq([ "Kain" ])

    post "/admin/orders", params: { record: { number: "" } }
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "ignores attributes that are not in the form" do
    patch "/admin/orders/#{order.id}", params: { record: { number: "A-9", total: 5 } }
    expect(order.reload).to have_attributes(number: "A-9", total: nil)
  end

  it "pluralizes resource labels when the app has no i18n plural" do
    get "/admin/line_items"
    expect(response.body).to include("Line items", "Orders", "Customers")
  end

  it "keeps screen-reader text inside the scrolling table wrapper" do
    get "/admin/orders"
    expect(response.body).to include('class="relative max-h-[calc(100dvh-8rem)] scroll-pt-12 overflow-auto"')
  end

  it "shows a status as a dot plus the word, and as a pill only when asked" do
    get "/admin/orders"
    expect(response.body).to include("bg-warning").and include("Pending")
    expect(response.body).not_to include("ring-warning/25")
  end

  it "serves its own font and calls no third party" do
    get "/admin/orders"
    expect(response.body).to include("@font-face").and include("wibawa/plus-jakarta-sans-latin")
    expect(response.body).not_to match(/googleapis|gstatic/)

    Wibawa.config.font = :system
    get "/admin/orders"
    expect(response.body).not_to include("@font-face")
  ensure
    Wibawa.config.font = :bundled
  end

  it "gives the browser tab an icon, which the app can replace or remove" do
    get "/admin"
    icon = response.body[/<link rel="icon"[^>]*>/]
    expect(icon).to include('type="image/svg+xml"', "/assets/wibawa/favicon-")
    get icon[/href="([^"]+)"/, 1]
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("<svg")

    Wibawa.config.favicon = "https://example.com/own.png"
    get "/admin"
    expect(response.body).to include('href="https://example.com/own.png"')
    Wibawa.config.favicon = false
    get "/admin"
    expect(response.body).not_to include('rel="icon"')
  ensure
    Wibawa.config.favicon = nil
  end

  it "exports CSV" do
    get "/admin/orders.csv"
    expect(response.media_type).to eq("text/csv")
    expect(response.body).to include("A-1")
  end

  it "exports a sorted CSV in primary-key batches, never by OFFSET" do
    stub_const("Wibawa::CsvExporter::BATCH_SIZE", 2)
    %w[C-3 B-2 D-4].each { |number| Order.create!(number: number, customer: customer, total: 1) }

    queries = []
    callback = ->(*, payload) { queries << payload[:sql] if payload[:sql].include?(%q(FROM "orders")) }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      get "/admin/orders.csv", params: { sort: "number", direction: "desc" }
      expect(response.body.lines.drop(1).map { |line| line[/[A-D]-\d/] }).to eq(%w[D-4 C-3 B-2 A-1])
    end
    expect(queries.grep(/OFFSET/)).to eq([])
    expect(queries.grep(/"orders"."id" IN/).size).to eq(2) # four orders, two per batch
  end

  it "runs member and batch actions" do
    post "/admin/orders/#{order.id}/actions/pay"
    expect(order.reload).to be_paid

    post "/admin/orders/batch", params: { batch_action: "destroy", ids: [ order.id ] }
    expect(Order.exists?(order.id)).to be(false)
  end

  it "enforces authorization on every write" do
    Wibawa.config.authorize_with { |_user, action, _subject| %i[index show].include?(action) }

    get "/admin/orders/new"
    expect(response).to have_http_status(:forbidden)

    patch "/admin/orders/#{order.id}", params: { record: { number: "X" } }
    delete "/admin/orders/#{order.id}"
    post "/admin/orders/batch", params: { batch_action: "destroy", ids: [ order.id ] }
    post "/admin/orders/#{order.id}/actions/pay"
    expect(order.reload).to have_attributes(number: "A-1", status: "pending")

    get "/admin/orders"
    expect(response.body).not_to include("/admin/orders/new")
  end

  describe "the row delete button" do
    around do |example|
      ActionController::Base.allow_forgery_protection = true
      example.run
    ensure
      ActionController::Base.allow_forgery_protection = false
    end

    it "works without script, and only with the token of the form all rows share" do
      doomed = Order.create!(number: "Z-9", customer: Customer.create!(name: "Tika"))
      get "/admin/orders"
      token = response.body[/<form id="wb-row-form"[^>]*><input type="hidden" name="authenticity_token" value="([^"]+)"/, 1]
      expect(token).to be_present
      expect(response.body).to include(%(formaction="/admin/orders/#{doomed.id}" name="_method" value="delete"))

      expect { post "/admin/orders/#{doomed.id}", params: { _method: "delete" } }.to raise_error(ActionController::InvalidAuthenticityToken)
      expect(Order.exists?(doomed.id)).to be(true)

      post "/admin/orders/#{doomed.id}", params: { _method: "delete", authenticity_token: token }
      expect(response).to have_http_status(:see_other)
      expect(Order.exists?(doomed.id)).to be(false)
    end
  end
end
