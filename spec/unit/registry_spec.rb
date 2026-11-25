require "spec_helper"
require_relative "../support/fake_models"

RSpec.describe Wibawa::Registry do
  before do
    @registry = Wibawa::Registry.new
  end

  def resource(name, **menu)
    r = Wibawa::Resource.new(name, as: name.downcase)
    r.menu(**menu) unless menu.empty?
    r
  end

  it "register fetch and missing" do
    @registry.register(resource("Order"))
    expect(@registry.fetch("order").key).to eq("order")
    expect { @registry.fetch("missing") }.to raise_error(Wibawa::ResourceNotFound)
  end

  it "menu groups sorted by priority" do
    @registry.register(resource("Order", group: "Sales", priority: 2, label: "Orders"))
    @registry.register(resource("Customer", group: "Sales", priority: 1, label: "Customers"))
    @registry.register(resource("User", label: "Users"))
    @registry.register(resource("Setting", group: "System", priority: 9, label: "Settings"))
    hidden = resource("Secret")
    hidden.menu(false)
    @registry.register(hidden)

    menu = @registry.menu
    expect(menu.map(&:first)).to eq([ nil, "Sales", "System" ])
    expect(menu[1].last.map(&:label)).to eq(%w[Customers Orders])
    expect(menu.flat_map(&:last).any? { |r| r.key == "secret" }).to be_falsey
  end

  it "for model" do
    @registry.register(Wibawa::Resource.new("Order"))
    expect(@registry.for_model(FakeModel).key).to eq("orders")
  end
end
