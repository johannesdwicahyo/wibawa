Wibawa.resource Customer do
  form do
    field :name
    field :orders
  end
end
Wibawa.resource LineItem do
  index density: :compact
end

Wibawa.resource Order do
  scope :all, default: true
  scope :pending
  search :number, "customer.name"
  import key: :number
  filter :status
  filter :customer
  filter :line_items
  filter "line_items.product"
  filter "line_items.position"
  filter "customer.name", label: "Customer name"

  form do
    field :number
    field :status
    field :customer
    has_many :line_items, sortable: :position do
      field :product
    end
  end

  member_action(:pay) { |order| order.paid! }
end

Wibawa.report :orders_by_status do
  title "Orders by status"
  param :number, default: "%"
  sql "SELECT status, COUNT(*) AS orders, SUM(total) AS revenue FROM orders WHERE number LIKE :number GROUP BY status ORDER BY status"
  column :status
  column :orders
  column :revenue, as: :money
  chart x: :status, y: :orders
end

Wibawa.report :orders_per_customer do
  query { |_params| Order.joins(:customer).group("customers.name").count }
end

Wibawa.page :maintenance do
  title "Maintenance"
  description "Housekeeping."
  menu group: "System", icon: "cog"
  content { tag.p("Pending orders: #{Order.pending.count}", id: "pending") }

  action :pay_all, confirm: "Pay every order?" do
    "#{Order.pending.update_all(status: 1)} orders paid"
  end
end

Wibawa.page :about do
  view "admin/about"
end

Wibawa.report :total_by_number do
  query { |_params| Order.group(:number).order(:number).sum(:total) }
  column :number
  column :total, as: :money
  chart :line, x: :number, y: :total
end

Wibawa.report :total_and_double do
  sql "SELECT number, total, total * 2 AS doubled, status FROM orders ORDER BY number"
  column :number
  column :total, as: :money
  column :doubled, as: :money
  chart :line, x: :number, y: %i[total doubled]
end

Wibawa.report :status_compare do
  sql "SELECT status, COUNT(*) AS orders, SUM(total) AS revenue FROM orders GROUP BY status ORDER BY status"
  chart x: :status, y: %i[orders revenue]
end

Wibawa.report :order_list do
  sql "SELECT number, total FROM orders ORDER BY number; "
end

Wibawa.report :order_relation do
  query { |_params| Order.select(:number, :total).order(:number) }
end

Wibawa.report :top_orders do
  sql "SELECT number FROM orders ORDER BY number LIMIT 2"
end
