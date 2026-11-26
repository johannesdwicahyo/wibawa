require "spec_helper"

RSpec.describe "Wibawa CSV import", type: :request do
  let!(:customer) { Customer.create!(name: "Sari") }
  let!(:order) { Order.create!(number: "A-1", customer: customer) }

  def upload(csv, **params)
    file = Tempfile.new([ "orders", ".csv" ]).tap { |f| f.write(csv) and f.rewind }
    post "/admin/orders/import", params: { file: Rack::Test::UploadedFile.new(file.path, "text/csv"), **params }
  end

  it "is offered only on resources that turn it on" do
    get "/admin/orders"
    expect(response.body).to include('href="/admin/orders/import"')
    get "/admin/orders/import"
    expect(response.body).to include("customer_id", "A row whose Number already exists updates that record.")

    get "/admin/orders/import.csv"
    expect(response.body).to eq("number,status,customer_id\n")

    get "/admin/customers"
    expect(response.body).not_to include("/admin/customers/import")
    get "/admin/customers/import"
    expect(response).to have_http_status(:not_found)
  end

  it "creates new rows and updates rows that match the key" do
    upload "﻿Number,Status,customer_id\nB-2,paid,#{customer.id}\nA-1,paid,\n'=C-3,,#{customer.id}\n"

    expect(response).to redirect_to("/admin/orders")
    expect(flash[:notice]).to eq("Import finished: 2 created, 1 updated.")
    expect(Order.order(:number).pluck(:number, :status)).to eq([ [ "=C-3", "pending" ], [ "A-1", "paid" ], [ "B-2", "paid" ] ])
    expect(order.reload.customer).to eq(customer) # the empty cell did not clear it
  end

  it "checks a file without keeping anything, and shows what it would do" do
    Wibawa.config.audit_log = true
    upload "number,status,customer_id\nB-2,paid,#{customer.id}\nA-1,paid,\nA-1,,\n", dry_run: "1"

    expect(response).to have_http_status(:ok)
    preview = response.body[/<section[^>]*data-wb-import-preview.*?<\/section>/m]
    expect(preview).to include("would create 1 and update 2", "Nothing has been imported yet", "The first 3 rows", "B-2", "No change")
    expect(preview.scan(/<tr class="align-top">.*?<\/tr>/m).map { |row| helpers_text(row) })
      .to eq([ "2 Create B-2 Number: —→B-2 Status: pending→paid Customer: —→#{customer.id}", "3 Update A-1 Status: pending→paid", "4 Update A-1 No change" ])
    expect(Order.pluck(:number, :status)).to eq([ [ "A-1", "pending" ] ])
    expect(Wibawa::AuditEntry.count).to eq(0)

    upload "number,status,customer_id\nB-2,paid,#{customer.id}\n,paid,#{customer.id}\n", dry_run: "1"
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Line 3:")
    expect(response.body).not_to include("data-wb-import-preview")
    expect(Order.count).to eq(1)
  ensure
    Wibawa.config.audit_log = false
  end

  def helpers_text(html) = ActionController::Base.helpers.strip_tags(html).squish

  it "imports nothing when any row is invalid, and says which" do
    upload "number,status,customer_id\nB-2,paid,#{customer.id}\n,paid,#{customer.id}\nD-4,nonsense,#{customer.id}\n"

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Nothing was imported", "Line 3:", "Number can&#39;t be blank", "Line 4:", "nonsense")
    expect(Order.pluck(:number)).to eq([ "A-1" ])
  end

  it "rejects columns it does not know, including ones the form does not expose" do
    upload "number,total\nB-2,99\n"
    expect(response.body).to include("Unknown columns: total")
    expect(Order.count).to eq(1)
  end

  it "authorizes an update on the stored record, not on the row's values" do
    # Only pending orders may be changed; the row tries to pass by saying it is pending.
    order.paid!
    Wibawa.config.authorize_with { |_user, action, subject| action != :update || subject.pending? }
    upload "number,status\nA-1,pending\n"

    expect(response.body).to include("Line 2:", "permission")
    expect(order.reload).to be_paid
  end

  it "is authorized as a whole and per row" do
    Wibawa.config.authorize_with { |_user, action, _subject| action != :import }
    upload "number,customer_id\nB-2,#{customer.id}\n"
    expect(Order.count).to eq(1)

    Wibawa.config.authorize_with { |_user, action, _subject| action != :update }
    upload "number,customer_id\nB-2,#{customer.id}\nA-1,#{customer.id}\n"
    expect(response.body).to include("Line 3:", "permission")
    expect(Order.count).to eq(1)
  end
end
