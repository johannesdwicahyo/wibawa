require "spec_helper"

RSpec.describe "Wibawa without authentication configured", type: :request do
  def in_production
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("production"))
  end

  it "serves in development and test" do
    get "/admin"
    expect(response).to have_http_status(:ok)
  end

  it "refuses every request anywhere else" do
    in_production
    [ "/admin", "/admin/orders", "/admin/orders.csv", "/admin/reports/orders_by_status", "/admin/-/search?q=a" ].each do |path|
      get path
      expect(response).to have_http_status(:forbidden), path
      expect(response.body).to include("config.authenticate_with")
    end

    expect { post "/admin/customers", params: { record: { name: "Mallory" } } }.not_to change(Customer, :count)
    expect(response).to have_http_status(:forbidden)
  end

  it "serves once a gate is configured or declared to be elsewhere" do
    in_production
    Wibawa.config.authenticate_with { head :unauthorized unless params[:key] == "s3cret" }
    get "/admin"
    expect(response).to have_http_status(:unauthorized)
    get "/admin", params: { key: "s3cret" }
    expect(response).to have_http_status(:ok)

    %i[parent_controller none].each do |elsewhere|
      Wibawa.config.authenticate_with elsewhere
      get "/admin"
      expect(response).to have_http_status(:ok)
    end

    expect { Wibawa.config.authenticate_with :nope }.to raise_error(ArgumentError)
    expect { Wibawa.config.authenticate_with }.to raise_error(ArgumentError)
  end
end
