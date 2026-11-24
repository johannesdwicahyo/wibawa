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

  describe "has_many fields" do
    let!(:other) { Order.create!(number: "B-2", customer: budi) }

    it "is a multi-select while the table is short, and keeps chosen ids it does not list" do
      get "/admin/customers/#{sari.id}/edit"
      expect(response.body).to include('multiple="multiple"', ">A-1<", ">B-2<")

      limited = Class.new(Wibawa::Authorization::Allow) do
        def scope(relation) = relation.klass == Order ? relation.where.not(number: "A-1") : relation
      end
      Wibawa.config.authorization = limited
      get "/admin/customers/#{sari.id}/edit"
      expect(response.body).not_to include(">A-1<")
      expect(response.body).to include(%(<input type="hidden" name="record[order_ids][]" value="#{order.id}"))
    end

    it "becomes a search box with one chip per chosen record" do
      stub_const("Wibawa::ComboboxComponent::THRESHOLD", 1)
      get "/admin/customers/#{sari.id}/edit"
      expect(response.body).to include("data-multiple", 'data-url="/admin/customers/options/Order"', "data-wb-combo-chip-template",
                                       %(name="record[order_ids][]" value="#{order.id}"), ">A-1<")
      expect(response.body).not_to include(">B-2<", "multiple=\"multiple\"")

      get "/admin/customers/options/Order", params: { q: "B-2" }
      expect(response.body).to include(%(data-value="#{other.id}"))

      patch "/admin/customers/#{sari.id}", params: { record: { order_ids: ["", order.id, other.id] } }
      expect(sari.reload.orders).to contain_exactly(order, other)
    end
  end

  it "searches the target model, and only models the resource points at" do
    get "/admin/orders/options/Customer", params: { q: "bud" }
    expect(response.body).to include(%(data-value="#{budi.id}"), "Budi")
    expect(response.body).not_to include("Sari", "<html")

    get "/admin/orders/options/Customer", params: { q: "zzz" }
    expect(response.body).to include("Nothing matches.")

    get "/admin/orders/options/Order" # no field or filter of orders chooses an Order
    expect(response).to have_http_status(:not_found)
    get "/admin/customers/options/Customer"
    expect(response).to have_http_status(:not_found)
  end

  it "never names a record outside the user's scope" do
    scoped = Class.new(Wibawa::Authorization::Allow) do
      def scope(relation) = relation.klass == Customer ? relation.where.not(name: "Budi") : relation
    end
    Wibawa.config.authorization = scoped

    get "/admin/orders?q[customer]=#{budi.id}" # plain select: Budi is not offered
    expect(response.body).not_to include("Budi")

    stub_const("Wibawa::ComboboxComponent::THRESHOLD", 0)
    get "/admin/orders?q[customer]=#{budi.id}" # search box and chip: the id, not the name
    expect(response.body).to include("##{budi.id}")
    expect(response.body).not_to include("Budi")

    get "/admin/orders/options/Customer", params: { q: "bud" }
    expect(response.body).not_to include("Budi")
  end

  it "is closed to users who cannot use the resource" do
    Wibawa.config.authorize_with { |_user, _action, subject| subject != Order }
    get "/admin/orders/options/Customer"
    expect(response).to have_http_status(:forbidden)
  end
end
