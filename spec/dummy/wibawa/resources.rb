Wibawa.resource Customer do
  form do
    field :name
    field :orders
  end
end
Wibawa.resource LineItem

Wibawa.resource Order do
  scope :all, default: true
  scope :pending
  search :number, "customer.name"
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
