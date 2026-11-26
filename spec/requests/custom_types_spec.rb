require "spec_helper"

RSpec.describe "Wibawa custom column and field types", type: :request do
  let!(:customer) { Customer.create!(name: "Sari <b>") }

  before do
    Wibawa.column_type(:shout) { |value, record, column| tag.strong("#{value.upcase}!", data: { record: record.id, column: column.name }) }
    Wibawa.column_type(:plain) { |value| "<i>#{value}</i>" }
    Wibawa.field_type(:shout) { |form, attribute, html_options| form.text_field(attribute, html_options.merge(data: { shout: true }, placeholder: "LOUD")) }
    Wibawa.resource Customer do
      index do
        column :name, as: :shout
        column :name, as: :plain, label: "Plain"
        column(:nothing, as: :shout) { nil }
      end
      form { field :name, as: :shout, hint: "Speak up" }
    end
  end

  after do
    Wibawa.config.column_types.clear
    Wibawa.config.field_types.clear
    Wibawa.load!
  end

  it "formats a column with the registered block, in the view, and escapes what it returns" do
    get "/admin/customers"
    expect(response.body).to include(%(<strong data-record="#{customer.id}" data-column="name">SARI &lt;B&gt;!</strong>)) # helpers work; the value is escaped
    expect(response.body).to include("&lt;i&gt;Sari &lt;b&gt;&lt;/i&gt;") # a plain string is escaped whole
    expect(response.body).to include("—") # not called for nil: the usual empty mark

    get "/admin/customers.csv"
    expect(response.body).to include("Sari <b>") # the export keeps the plain value
    expect(response.body).not_to include("SARI")
  end

  it "draws a field with the registered block inside the usual label, hint and errors, and saves it" do
    get "/admin/customers/#{customer.id}/edit"
    field = response.body[/<div[^>]*data-wb-field="name".*?<\/div>/m]
    expect(field).to include("<label", 'data-shout="true"', 'placeholder="LOUD"', 'name="record[name]"', "Speak up")

    patch "/admin/customers/#{customer.id}", params: { record: { name: "Budi" } }
    expect(customer.reload.name).to eq("Budi")
  end

  it "lets a registered type replace a built-in one, and insists on a block" do
    order = Order.create!(number: "A-1", customer: customer, total: 5)
    get "/admin/reports/orders_by_status"
    expect(response.body).not_to include("five-ish")
    Wibawa.column_type(:money) { |_value| "five-ish" }
    get "/admin/reports/orders_by_status"
    expect(response.body).to include("five-ish")
    expect(order).to be_persisted

    expect { Wibawa.column_type(:nope) }.to raise_error(ArgumentError, /needs a block/)
    expect { Wibawa.field_type(:nope) }.to raise_error(ArgumentError, /needs a block/)
  end
end
