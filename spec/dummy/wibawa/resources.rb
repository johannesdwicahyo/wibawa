Wibawa.resource Customer
Wibawa.resource LineItem

Wibawa.resource Order do
  scope :all, default: true
  scope :pending
  search :number, "customer.name"
  filter :status

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
