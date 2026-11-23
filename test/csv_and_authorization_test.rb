require_relative "test_helper"

class CsvExporterTest < Minitest::Test
  Row = Struct.new(:id, :number)

  class Rel
    def initialize(rows) = (@rows = rows)
    def order_values = []
    def find_each(batch_size:, &block) = @rows.each(&block)
  end

  class Presenter
    def plain(record, column) = record.public_send(column.name)
  end

  def test_streams_header_rows_and_blocks_formula_injection
    resource = Wibawa::Resource.new(FakeModel) { csv { column :id; column :number } }
    rows = [Row.new(1, "INV-1"), Row.new(2, "=HYPERLINK(\"x\")")]
    lines = Wibawa::CsvExporter.new(resource, Rel.new(rows), Presenter.new).lines.to_a
    assert_equal "﻿", lines[0]
    assert_equal "Id,Number\n", lines[1]
    assert_equal "1,INV-1\n", lines[2]
    assert lines[3].start_with?("2,\"'=HYPERLINK")
  end
end

class AuthorizationTest < Minitest::Test
  def teardown
    Wibawa.config.authorization = nil
  end

  def test_allow_by_default
    assert Wibawa::Authorization.build(nil).authorized?(:destroy, Object.new)
  end

  def test_proc_adapter
    Wibawa.config.authorize_with { |user, action, _| user == :admin || action == :index }
    assert Wibawa::Authorization.build(:admin).authorized?(:destroy, nil)
    assert Wibawa::Authorization.build(:staff).authorized?(:index, nil)
    refute Wibawa::Authorization.build(:staff).authorized?(:destroy, nil)
  end

  def test_fallbacks
    assert_equal :index, Wibawa::Authorization.fallback_for(:export)
    assert_equal :destroy, Wibawa::Authorization.fallback_for(:batch_destroy)
    assert_equal :update, Wibawa::Authorization.fallback_for(:batch_mark_paid)
    assert_equal :update, Wibawa::Authorization.fallback_for(:refund)
  end

  def test_badge_colors
    assert_equal :success, Wibawa.config.badge_color_for("Paid")
    assert_equal :danger, Wibawa.config.badge_color_for(:cancelled)
    assert_equal :neutral, Wibawa.config.badge_color_for("something")
  end
end
