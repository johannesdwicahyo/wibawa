require_relative "test_helper"

class PaginatorTest < Minitest::Test
  class FakeRelation
    def initialize(total) = (@rows = (1..total).to_a)
    def limit(n) = (@limit = n; self)
    def offset(n) = (@offset = n; self)
    def to_a = @rows.drop(@offset).first(@limit)
    def except(*) = self
    def count(*) = @rows.size
  end

  def test_counted
    p = Wibawa::Paginator.new(FakeRelation.new(120), page: 2, per_page: 50)
    assert_equal (51..100).to_a, p.records
    assert_equal 3, p.total_pages
    assert p.next?
    assert p.prev?
    assert_equal [51, 100], [p.first_index, p.last_index]
  end

  def test_uncounted_detects_next_page
    p = Wibawa::Paginator.new(FakeRelation.new(120), page: 3, per_page: 50, count: false)
    assert_equal 20, p.records.size
    refute p.next?
    assert_nil p.total_pages
    p = Wibawa::Paginator.new(FakeRelation.new(120), page: 1, per_page: 50, count: false)
    assert p.next?
    assert_equal 50, p.records.size
  end

  def test_window_with_gaps
    p = Wibawa::Paginator.new(FakeRelation.new(1000), page: 10, per_page: 25)
    assert_equal [1, :gap, 8, 9, 10, 11, 12, :gap, 40], p.window
  end

  def test_bad_page_falls_back_to_one
    assert_equal 1, Wibawa::Paginator.new(FakeRelation.new(5), page: "-3", per_page: 10).page
  end
end
