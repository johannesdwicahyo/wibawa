require "spec_helper"

RSpec.describe "Wibawa reports", type: :request do
  let!(:customer) { Customer.create!(name: "Sari") }

  before do
    Order.create!(number: "A-1", customer: customer, total: 10)
    Order.create!(number: "A-2", customer: customer, total: 15)
    Order.create!(number: "=B-1", customer: customer, total: 5, status: :paid)
  end

  it "shows the table, the chart and a sidebar link" do
    get "/admin/reports/orders_by_status"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Orders by status", ">Revenue<", "$25.00", 'role="img"', "width: 100.0%", "width: 50.0%")

    get "/admin"
    expect(response.body).to include('href="/admin/reports/orders_by_status"', ">Reports<")
  end

  it "binds params instead of interpolating them" do
    get "/admin/reports/orders_by_status", params: { p: { number: "A-%" } }
    expect(response.body).to include("$25.00")
    expect(response.body).not_to include("$5.00")

    get "/admin/reports/orders_by_status", params: { p: { number: "x' OR '1'='1" } }
    expect(response.body).to include("This report has no rows.")
  end

  it "accepts a grouped query and exports CSV without live formulas" do
    get "/admin/reports/orders_per_customer"
    expect(response.body).to include(">Name<", ">Sari<", ">Value<")

    get "/admin/reports/orders_per_customer.csv"
    expect(response.media_type).to eq("text/csv")
    expect(response.body).to include("Name,Value\nSari,3\n")
  end

  it "is authorized like everything else and 404s for unknown reports" do
    Wibawa.config.authorize_with { |_user, _action, subject| !subject.is_a?(Wibawa::Report) }
    get "/admin/reports/orders_by_status"
    expect(response).to have_http_status(:forbidden)
    get "/admin"
    expect(response.body).not_to include("/admin/reports/")

    get "/admin/reports/nope"
    expect(response).to have_http_status(:not_found)
  end
end
