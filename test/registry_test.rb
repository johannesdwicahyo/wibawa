require_relative "test_helper"

class RegistryTest < Minitest::Test
  def setup
    @registry = Wibawa::Registry.new
  end

  def resource(name, **menu)
    r = Wibawa::Resource.new(name, as: name.downcase)
    r.menu(**menu) unless menu.empty?
    r
  end

  def test_register_fetch_and_missing
    @registry.register(resource("Order"))
    assert_equal "order", @registry.fetch("order").key
    assert_raises(Wibawa::ResourceNotFound) { @registry.fetch("missing") }
  end

  def test_menu_groups_sorted_by_priority
    @registry.register(resource("Order", group: "Sales", priority: 2, label: "Orders"))
    @registry.register(resource("Customer", group: "Sales", priority: 1, label: "Customers"))
    @registry.register(resource("User", label: "Users"))
    @registry.register(resource("Setting", group: "System", priority: 9, label: "Settings"))
    hidden = resource("Secret")
    hidden.menu(false)
    @registry.register(hidden)

    menu = @registry.menu
    assert_equal [nil, "Sales", "System"], menu.map(&:first)
    assert_equal %w[Customers Orders], menu[1].last.map(&:label)
    refute(menu.flat_map(&:last).any? { |r| r.key == "secret" })
  end

  def test_for_model
    @registry.register(Wibawa::Resource.new("Order"))
    assert_equal "orders", @registry.for_model(FakeModel).key
  end
end
