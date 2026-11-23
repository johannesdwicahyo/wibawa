require_relative "test_helper"

class DashboardTest < Minitest::Test
  def test_stats_and_tables
    d = Wibawa::Dashboard.new do
      stat("Orders", as: :number) { 3 }
      table("Latest", resource: :orders) { [] }
      table("Custom", columns: %i[id total]) { [] }
    end
    assert_equal ["Orders"], d.stats.map(&:label)
    assert_equal 3, d.stats.first.block.call
    assert_equal "orders", d.tables.first.options[:resource]
    assert_nil d.tables.first.builder
    assert_equal %i[id total], d.tables.last.builder.columns.map(&:name)
  end
end
