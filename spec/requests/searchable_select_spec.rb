require "spec_helper"

RSpec.describe "Wibawa searchable select", type: :request do
  let!(:sari) { Customer.create!(name: "Sari") }
  let!(:budi) { Customer.create!(name: "Budi") }
  let!(:order) { Order.create!(number: "A-1", customer: sari) }

  it "keeps a plain select while the table is short" do
    get "/admin/orders/#{order.id}/edit"
    expect(response.body).to include('<select', "Budi")
    expect(response.body).not_to include("data-wb-combobox")
  end

  context "when the table is too long to list" do
    before { stub_const("Wibawa::ComboboxComponent::THRESHOLD", 1) }

    it "renders a search box holding the current choice, in forms and filters" do
      get "/admin/orders/#{order.id}/edit"
      expect(response.body).to include('data-wb-combobox', 'data-url="/admin/orders/options/Customer"',
                                       %(name="record[customer_id]" value="#{sari.id}"), 'value="Sari"')
      expect(response.body).not_to include(">Budi<")

      get "/admin/orders?q[customer]=#{budi.id}"
      expect(response.body).to include(%(name="q[customer]" value="#{budi.id}" form="wb-index-form"), "Remove filter: Customer", "Budi")
    end

    it "still saves the chosen id" do
      patch "/admin/orders/#{order.id}", params: { record: { customer_id: budi.id } }
      expect(order.reload.customer).to eq(budi)
    end
  end

  it "searches the target model, and only models the resource points at" do
    get "/admin/orders/options/Customer", params: { q: "bud" }
    expect(response.body).to include(%(data-value="#{budi.id}"), "Budi")
    expect(response.body).not_to include("Sari", "<html")

    get "/admin/orders/options/Customer", params: { q: "zzz" }
    expect(response.body).to include("Nothing matches.")

    get "/admin/orders/options/LineItem"
    expect(response).to have_http_status(:not_found)
    get "/admin/customers/options/Customer"
    expect(response).to have_http_status(:not_found)
  end

  it "is closed to users who cannot use the resource" do
    Wibawa.config.authorize_with { |_user, _action, subject| subject != Order }
    get "/admin/orders/options/Customer"
    expect(response).to have_http_status(:forbidden)
  end
end
