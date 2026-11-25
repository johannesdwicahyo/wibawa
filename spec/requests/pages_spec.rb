require "spec_helper"

RSpec.describe "Wibawa custom pages", type: :request do
  let!(:customer) { Customer.create!(name: "Sari") }
  let!(:order) { Order.create!(number: "A-1", customer: customer) }

  it "renders a content block or an app template inside the admin, with menu entries" do
    get "/admin/pages/maintenance"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Maintenance", "Housekeeping.", '<p id="pending">Pending orders: 1</p>',
                                     'action="/admin/pages/maintenance/pay_all"', ">System<", 'href="/admin/pages/about"')

    get "/admin/pages/about"
    expect(response.body).to include('<p id="about">About Admin, 1 customers.</p>', "data-wb-sidebar")
  end

  it "runs an action and reports back" do
    post "/admin/pages/maintenance/pay_all"
    expect(response).to redirect_to("/admin/pages/maintenance")
    expect(flash[:notice]).to eq("1 orders paid")
    expect(order.reload).to be_paid

    post "/admin/pages/maintenance/nope"
    expect(response).to have_http_status(:not_found)
  end

  it "is authorized per page and per action, and 404s for unknown pages" do
    Wibawa.config.authorize_with { |_user, action, subject| !(subject.is_a?(Wibawa::Page) && (subject.key == "about" || action == :pay_all)) }

    get "/admin/pages/about"
    expect(response).to have_http_status(:forbidden)
    get "/admin/pages/maintenance"
    expect(response.body).not_to include("pay_all", "/admin/pages/about")
    post "/admin/pages/maintenance/pay_all"
    expect(order.reload).to be_pending

    get "/admin/pages/nope"
    expect(response).to have_http_status(:not_found)
  end
  it "shares a sidebar heading with resources in a group of the same name" do
    Wibawa.registry.fetch("line_items").menu(group: "System")
    get "/admin"
    expect(response.body.scan(">System</p>").size).to eq(1)
    expect(response.body).to match(%r{>System</p>.*?href="/admin/line_items".*?href="/admin/pages/maintenance"}m)
  ensure
    Wibawa.load! # put the menu back
  end
end
