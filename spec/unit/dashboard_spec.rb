require "spec_helper"
require_relative "../support/fake_models"

RSpec.describe Wibawa::Dashboard do
  it "stats and tables" do
    d = Wibawa::Dashboard.new do
      stat("Orders", as: :number) { 3 }
      table("Latest", resource: :orders) { [] }
      table("Custom", columns: %i[id total]) { [] }
    end
    expect(d.stats.map(&:label)).to eq([ "Orders" ])
    expect(d.stats.first.block.call).to eq(3)
    expect(d.tables.first.options[:resource]).to eq("orders")
    expect(d.tables.first.builder).to be_nil
    expect(d.tables.last.builder.columns.map(&:name)).to eq(%i[id total])
  end
end
