require "spec_helper"

RSpec.describe "Wibawa filters on associations", type: :request do
  let!(:sari) { Customer.create!(name: "Sari") }
  let!(:budi) { Customer.create!(name: "Budi") }
  let!(:batik) { Order.create!(number: "A-1", customer: sari, line_items: [LineItem.new(product: "Batik", position: 1), LineItem.new(product: "Batik tulis", position: 2)]) }
  let!(:kain) { Order.create!(number: "B-2", customer: budi, line_items: [LineItem.new(product: "Kain", position: 5)]) }
  let!(:empty) { Order.create!(number: "C-3", customer: budi) }

  def numbers(query)
    get "/admin/orders.csv", params: { q: query }
    response.body.lines.drop(1).map { |line| line.split(",")[1] }.sort
  end

  it "filters by a chosen has_many record" do
    expect(numbers(line_items: kain.line_items.first.id)).to eq(["B-2"])
    expect(numbers(line_items: "")).to eq(%w[A-1 B-2 C-3])
  end

  it "filters by a column of an associated table, without duplicating rows" do
    expect(numbers("line_items.product" => "batik")).to eq(["A-1"]) # two matching items, one row
    expect(numbers("line_items.position_from" => 2, "line_items.position_to" => 9)).to eq(%w[A-1 B-2])
    expect(numbers("customer.name" => "bud")).to eq(%w[B-2 C-3])
    expect(numbers("line_items.product" => "x' OR '1'='1")).to eq([])
  end

  it "renders each as the right control, with chips" do
    get "/admin/orders", params: { q: { line_items: kain.line_items.first.id, "line_items.product" => "Kain", "line_items.position_from" => 1 } }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('name="q[line_items]"', 'id="wb-filter-line_items-product"', 'name="q[line_items.position_from]"',
                                     "Remove filter: Line items", "Remove filter: Line items product", "Remove filter: Line items position")
    expect(response.body).to include(">B-2<")
    expect(response.body).not_to include(">A-1<")
  end

  it "offers has_many filter choices through the search box when there are many" do
    stub_const("Wibawa::ComboboxComponent::THRESHOLD", 1)
    get "/admin/orders"
    expect(response.body).to include('data-url="/admin/orders/options/LineItem"')
    get "/admin/orders/options/LineItem", params: { q: "kain" }
    expect(response.body).to include(%(data-value="#{kain.line_items.first.id}"))
    expect(response.body).not_to include(%(data-value="#{batik.line_items.first.id}"))
  end
end
