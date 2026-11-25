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

  it "draws a line chart with a zero-based value axis" do
    get "/admin/reports/total_by_number"
    # =B-1 5, A-1 10, A-2 15 on an axis from 0 to 15: a third of the way across each, rising.
    expect(response.body).to include('points="16.67,66.67 50.0,33.33 83.33,0.0"', "$15.00", "$7.50", "$0.00", "A-2: <span", "stroke: var(--wb-primary-effective)")
    expect(response.body).not_to include("--wb-series-") # one series: brand colour, no legend
    expect(response.body).not_to include("width: 100.0%") # no bars on a line chart

    expect { Wibawa::Report.new(:x) { query { [] } and chart(:pie, x: :a, y: :b) } }.to raise_error(Wibawa::Error, /Unknown chart type/)
  end

  it "draws several series on one axis, each in its own fixed colour" do
    get "/admin/reports/total_and_double"
    # Totals 5, 10, 15 and their doubles on one axis from 0 to 30.
    expect(response.body).to include('points="16.67,83.33 50.0,66.67 83.33,50.0"', 'style="stroke: var(--wb-series-1)"',
                                     'points="16.67,66.67 50.0,33.33 83.33,0.0"', 'style="stroke: var(--wb-series-2)"',
                                     "$30.00", 'aria-label="Total and Doubled"', "</span>Doubled</li>")

    get "/admin/reports/status_compare"
    # pending: 2 orders, 25 revenue; paid: 1 order, 5 revenue. One scale: 25 is the full width.
    expect(response.body).to include("width: 100.0%; background: var(--wb-series-2)", "width: 8.0%; background: var(--wb-series-1)",
                                     "width: 20.0%; background: var(--wb-series-2)", "grid-row: span 2")

    expect { Wibawa::Report.new(:x) { query { [] } and chart(x: :a, y: %i[a b c d e f g]) } }.to raise_error(Wibawa::Error, /1 to 6 series/)
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
