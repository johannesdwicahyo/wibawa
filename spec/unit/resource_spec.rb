require "spec_helper"
require_relative "../support/fake_models"

RSpec.describe Wibawa::Resource do
  def build(&block)
    Wibawa::Resource.new(FakeModel, &block)
  end

  it "key and custom key" do
    expect(build.key).to eq("orders")
    expect(Wibawa::Resource.new(FakeModel, as: :sales).key).to eq("sales")
    expect(Wibawa::Resource.new("LineItem").key).to eq("line_items")
  end

  it "scopes and default" do
    r = build do
      scope :all
      scope :pending, -> { where(status: :pending) }, default: true
      scope :recent, label: "Last 7 days"
    end
    expect(r.scopes.map(&:name)).to eq(%i[all pending recent])
    expect(r.default_scope.name).to eq(:pending)
    expect(r.find_scope("recent").label).to eq("Last 7 days")
    expect(r.find_scope("nope")).to be_nil
  end

  it "scope applies lambda symbol and all" do
    relation = Object.new
    def relation.where(**kw) = [ :where, kw ]
    def relation.recent = :recent_called
    expect(Wibawa::Scope.new(:pending, -> { where(status: :pending) }, {}).apply(relation)).to eq([ :where, { status: :pending } ])
    expect(Wibawa::Scope.new(:recent, nil, {}).apply(relation)).to eq(:recent_called)
    expect(Wibawa::Scope.new(:all, nil, {}).apply(relation)).to be(relation)
  end

  it "actions restriction expands new and edit" do
    r = build { actions :all, except: [ :edit, :destroy ] }
    expect(r.action?(:index)).to be_truthy
    expect(r.action?(:edit)).to be_falsey
    expect(r.action?(:update)).to be_falsey
    expect(r.action?(:destroy)).to be_falsey

    r = build { actions :index, :new }
    expect(r.action?(:create)).to be_truthy
    expect(r.action?(:show)).to be_falsey
  end

  it "builtin batch destroy follows destroy action" do
    expect(build.batch_actions.map(&:name)).to eq([ :destroy ])
    expect(build { actions :all, except: [ :destroy ] }.batch_actions).to be_empty
    expect(build { batch_action :destroy, false }.batch_actions).to be_empty

    r = build { batch_action(:mark_paid, confirm: true) { |orders| orders } }
    expect(r.batch_actions.map(&:name)).to eq(%i[mark_paid destroy])
    expect(r.selectable?).to be_truthy
  end

  it "index columns" do
    r = build do
      index per_page: 25, sort: "created_at desc", count: false do
        id_column
        column :total, as: :money
        column("Items") { |o| o.line_items.size }
        actions only: [ :show ]
      end
    end
    expect(r.index_columns.map(&:name)).to eq(%i[id total items])
    expect(r.index_columns.first.link?).to be_truthy
    expect(r.index_columns.last.label).to eq("Items")
    expect(r.index_options).to eq({ per_page: 25, sort: "created_at desc", count: false, density: nil })
    expect(r.row_actions[:only]).to eq([ :show ])
  end

  it "column sort expression" do
    col = Wibawa::Column.new(:total, {}, nil)
    expect(col.sort_expression(FakeModel)).to eq("total")
    expect(Wibawa::Column.new(:customer, {}, nil).sort_expression(FakeModel)).to be_nil
    expect(Wibawa::Column.new(:customer, { sortable: "customers.name" }, nil).sort_expression(FakeModel)).to eq("customers.name")
    expect(Wibawa::Column.new(:total, { sortable: false }, nil).sort_expression(FakeModel)).to be_nil
  end

  it "permitted attributes inferred from form" do
    r = build do
      form do
        field :number
        field :customer
        field :tags
        section "Details" do
          field :notes
        end
        has_many :line_items, sortable: true do
          field :quantity
        end
      end
    end
    expected = [ :number, :customer_id, { tag_ids: [] }, :notes, { line_items_attributes: %i[id _destroy quantity position] } ]
    expect(r.permitted_attributes).to eq(expected)
  end

  it "explicit permit params win" do
    r = build { permit_params :number, :status }
    expect(r.permitted_attributes).to eq(%i[number status])
  end

  it "member actions" do
    r = build { member_action(:refund, method: :patch, confirm: "Sure?", destructive: true) { |o| o } }
    action = r.find_member_action("refund")
    expect(action.http_method).to eq(:patch)
    expect(action.destructive?).to be_truthy
    expect(action.label).to eq("Refund")
  end

  it "filters and search" do
    r = build do
      filter :status, as: :select, collection: %w[pending paid]
      filter :created_at, as: :date_range
      search :number, "customer.name"
    end
    expect(r.filters.map(&:name)).to eq(%i[status created_at])
    expect(r.search_fields).to eq(%w[number customer.name])
  end

  it "controller blocks are collected" do
    r = build { controller { def scoped_collection = super } }
    expect(r.controller_blocks.size).to eq(1)
  end
end
