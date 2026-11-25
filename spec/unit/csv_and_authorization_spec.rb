require "spec_helper"
require_relative "../support/fake_models"

RSpec.describe Wibawa::CsvExporter do
  let(:row) { Struct.new(:id, :number) }
  let(:relation) do
    Class.new do
      def initialize(rows) = (@rows = rows)
      def order_values = []
      def find_each(batch_size:, &block) = @rows.each(&block)
    end
  end
  let(:presenter) { Class.new { def plain(record, column) = record.public_send(column.name) } }

  it "streams header rows and blocks formula injection" do
    resource = Wibawa::Resource.new(FakeModel) { csv { column :id; column :number } }
    rows = [ row.new(1, "INV-1"), row.new(2, "=HYPERLINK(\"x\")") ]
    lines = described_class.new(resource, relation.new(rows), presenter.new).lines.to_a
    expect(lines[0]).to eq("﻿")
    expect(lines[1]).to eq("Id,Number\n")
    expect(lines[2]).to eq("1,INV-1\n")
    expect(lines[3].start_with?("2,\"'=HYPERLINK")).to be_truthy
  end
end

RSpec.describe Wibawa::Authorization do
  after do
    Wibawa.config.authorization = nil
  end

  it "allow by default" do
    expect(Wibawa::Authorization.build(nil).authorized?(:destroy, Object.new)).to be_truthy
  end

  it "proc adapter" do
    Wibawa.config.authorize_with { |user, action, _| user == :admin || action == :index }
    expect(Wibawa::Authorization.build(:admin).authorized?(:destroy, nil)).to be_truthy
    expect(Wibawa::Authorization.build(:staff).authorized?(:index, nil)).to be_truthy
    expect(Wibawa::Authorization.build(:staff).authorized?(:destroy, nil)).to be_falsey
  end

  it "fallbacks" do
    expect(Wibawa::Authorization.fallback_for(:export)).to eq(:index)
    expect(Wibawa::Authorization.fallback_for(:batch_destroy)).to eq(:destroy)
    expect(Wibawa::Authorization.fallback_for(:batch_mark_paid)).to eq(:update)
    expect(Wibawa::Authorization.fallback_for(:refund)).to eq(:update)
  end

  it "badge colors" do
    expect(Wibawa.config.badge_color_for("Paid")).to eq(:success)
    expect(Wibawa.config.badge_color_for(:cancelled)).to eq(:danger)
    expect(Wibawa.config.badge_color_for("something")).to eq(:neutral)
  end
end
