require_relative "test_helper"

class ResourceTest < Minitest::Test
  def build(&block)
    Wibawa::Resource.new(FakeModel, &block)
  end

  def test_key_and_custom_key
    assert_equal "orders", build.key
    assert_equal "sales", Wibawa::Resource.new(FakeModel, as: :sales).key
    assert_equal "line_items", Wibawa::Resource.new("LineItem").key
  end

  def test_scopes_and_default
    r = build do
      scope :all
      scope :pending, -> { where(status: :pending) }, default: true
      scope :recent, label: "Last 7 days"
    end
    assert_equal %i[all pending recent], r.scopes.map(&:name)
    assert_equal :pending, r.default_scope.name
    assert_equal "Last 7 days", r.find_scope("recent").label
    assert_nil r.find_scope("nope")
  end

  def test_scope_applies_lambda_symbol_and_all
    relation = Object.new
    def relation.where(**kw) = [:where, kw]
    def relation.recent = :recent_called
    assert_equal [:where, { status: :pending }], Wibawa::Scope.new(:pending, -> { where(status: :pending) }, {}).apply(relation)
    assert_equal :recent_called, Wibawa::Scope.new(:recent, nil, {}).apply(relation)
    assert_same relation, Wibawa::Scope.new(:all, nil, {}).apply(relation)
  end

  def test_actions_restriction_expands_new_and_edit
    r = build { actions :all, except: [:edit, :destroy] }
    assert r.action?(:index)
    refute r.action?(:edit)
    refute r.action?(:update)
    refute r.action?(:destroy)

    r = build { actions :index, :new }
    assert r.action?(:create)
    refute r.action?(:show)
  end

  def test_builtin_batch_destroy_follows_destroy_action
    assert_equal [:destroy], build.batch_actions.map(&:name)
    assert_empty build { actions :all, except: [:destroy] }.batch_actions
    assert_empty build { batch_action :destroy, false }.batch_actions

    r = build { batch_action(:mark_paid, confirm: true) { |orders| orders } }
    assert_equal %i[mark_paid destroy], r.batch_actions.map(&:name)
    assert r.selectable?
  end

  def test_index_columns
    r = build do
      index per_page: 25, sort: "created_at desc", count: false do
        id_column
        column :total, as: :money
        column("Items") { |o| o.line_items.size }
        actions only: [:show]
      end
    end
    assert_equal %i[id total items], r.index_columns.map(&:name)
    assert r.index_columns.first.link?
    assert_equal "Items", r.index_columns.last.label
    assert_equal({ per_page: 25, sort: "created_at desc", count: false }, r.index_options)
    assert_equal [:show], r.row_actions[:only]
  end

  def test_column_sort_expression
    col = Wibawa::Column.new(:total, {}, nil)
    assert_equal "total", col.sort_expression(FakeModel)
    assert_nil Wibawa::Column.new(:customer, {}, nil).sort_expression(FakeModel)
    assert_equal "customers.name", Wibawa::Column.new(:customer, { sortable: "customers.name" }, nil).sort_expression(FakeModel)
    assert_nil Wibawa::Column.new(:total, { sortable: false }, nil).sort_expression(FakeModel)
  end

  def test_permitted_attributes_inferred_from_form
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
    expected = [:number, :customer_id, { tag_ids: [] }, :notes, { line_items_attributes: %i[id _destroy quantity position] }]
    assert_equal expected, r.permitted_attributes
  end

  def test_explicit_permit_params_win
    r = build { permit_params :number, :status }
    assert_equal %i[number status], r.permitted_attributes
  end

  def test_member_actions
    r = build { member_action(:refund, method: :patch, confirm: "Sure?", destructive: true) { |o| o } }
    action = r.find_member_action("refund")
    assert_equal :patch, action.http_method
    assert action.destructive?
    assert_equal "Refund", action.label
  end

  def test_filters_and_search
    r = build do
      filter :status, as: :select, collection: %w[pending paid]
      filter :created_at, as: :date_range
      search :number, "customer.name"
    end
    assert_equal %i[status created_at], r.filters.map(&:name)
    assert_equal %w[number customer.name], r.search_fields
  end

  def test_controller_blocks_are_collected
    r = build { controller { def scoped_collection = super } }
    assert_equal 1, r.controller_blocks.size
  end
end
