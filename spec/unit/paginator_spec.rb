require "spec_helper"
require_relative "../support/fake_models"

RSpec.describe Wibawa::Paginator do
  let(:relation) do
    Class.new do
      def initialize(total) = (@rows = (1..total).to_a)
      def limit(n) = (@limit = n; self)
      def offset(n) = (@offset = n; self)
      def to_a = @rows.drop(@offset).first(@limit)
      def except(*) = self
      def count(*) = @rows.size
    end
  end

  it "counted" do
    p = Wibawa::Paginator.new(relation.new(120), page: 2, per_page: 50)
    expect(p.records).to eq((51..100).to_a)
    expect(p.total_pages).to eq(3)
    expect(p.next?).to be_truthy
    expect(p.prev?).to be_truthy
    expect([ p.first_index, p.last_index ]).to eq([ 51, 100 ])
  end

  it "uncounted detects next page" do
    p = Wibawa::Paginator.new(relation.new(120), page: 3, per_page: 50, count: false)
    expect(p.records.size).to eq(20)
    expect(p.next?).to be_falsey
    expect(p.total_pages).to be_nil
    p = Wibawa::Paginator.new(relation.new(120), page: 1, per_page: 50, count: false)
    expect(p.next?).to be_truthy
    expect(p.records.size).to eq(50)
  end

  it "window with gaps" do
    p = Wibawa::Paginator.new(relation.new(1000), page: 10, per_page: 25)
    expect(p.window).to eq([ 1, :gap, 8, 9, 10, 11, 12, :gap, 40 ])
  end

  it "bad page falls back to one" do
    expect(Wibawa::Paginator.new(relation.new(5), page: "-3", per_page: 10).page).to eq(1)
  end
end
