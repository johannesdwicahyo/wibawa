require "spec_helper"

RSpec.describe "Wibawa record history from PaperTrail or Audited", type: :request do
  it "lists a PaperTrail model's versions, newest first, with who and what changed" do
    customer = PaperTrail.request(whodunnit: "Sari") { Customer.create!(name: "Toko Lama") }
    PaperTrail.request(whodunnit: "Budi") { customer.update!(name: "Toko <b>Baru</b>") }

    get "/admin/customers/#{customer.id}"
    history = response.body[/<section[^>]*data-wb-history.*?<\/section>/m]
    expect(history).to include("Change history", "Updated", "Created", "Budi", "Sari", "Toko Lama", "Toko &lt;b&gt;Baru&lt;/b&gt;")
    expect(history.index("Updated")).to be < history.index("Created")
    expect(history).not_to include("FILTERED", ">Id:<") # the id and timestamps are left out, not masked
  end

  it "lists an Audited model's audits" do
    product = Audited.audit_class.as_user("Sari") { Product.create!(name: "Teh") }
    Audited.audit_class.as_user("Budi") { product.update!(name: "Teh melati") }

    get "/admin/products/#{product.id}"
    history = response.body[/<section[^>]*data-wb-history.*?<\/section>/m]
    expect(history).to include("Updated", "Created", "Budi", "Sari", "Teh melati")
  end

  it "shows nothing for a model that keeps no history" do
    order = Order.create!(number: "A-1", customer: Customer.create!(name: "Sari"))
    get "/admin/orders/#{order.id}"
    expect(response.body).not_to include("data-wb-history")
  end

  it "lists only the attributes it is given, masks secrets, and stops at the limit" do
    customer = Customer.create!(name: "A")
    3.times { |i| customer.update!(name: "A#{i}") }

    expect(Wibawa::ModelHistory.for(customer, only: %w[name]).map(&:changes)).to all(include("name"))
    expect(Wibawa::ModelHistory.for(customer, only: []).map(&:changes)).to all(eq({}))
    expect(Wibawa::ModelHistory.for(customer, only: %w[name], limit: 2).map { |entry| entry.changes["name"].last }).to eq(%w[A2 A1])

    customer.versions.last.update_columns(object_changes: { "password_digest" => %w[old new], "api_key" => [ nil, "k" ] })
    expect(Wibawa::ModelHistory.for(customer, only: %w[password_digest api_key]).first.changes).to eq("password_digest" => "[FILTERED]", "api_key" => "[FILTERED]")
    expect(Wibawa::ModelHistory.for(Order.new, only: %w[number])).to be_nil
  end
end
