Wibawa.resource Order do
  menu group: "Sales", icon: "receipt", priority: 1

  scope :all, default: true
  scope :pending
  scope :paid
  scope :shipped
  scope :cancelled

  search :number, "customer.name"
  filter :status
  filter :customer
  filter :total, as: :number_range
  filter :created_at, as: :date_range
  filter "line_items.product", label: "Contains product"
  filter "customer.city", label: "City"

  index sort: { created_at: :desc } do
    column :number
    column :customer, sortable: "customers.name"
    column :status
    column("Items") { |order| order.line_items.size }
    column :total, as: :money
    column :created_at, label: "Placed"
    actions
  end

  show do
    attributes :number, :status, :customer
    row :total, as: :money
    row :created_at
    panel("Notes") { |order| order.notes.present? ? simple_format(order.notes) : "No notes." }
    table_for :line_items do
      column :product
      column :quantity
      column :unit_price, as: :money
    end
  end

  form do
    field :number
    field :customer
    field :status
    field :notes
    has_many :line_items, sortable: :position do
      field :product
      field :quantity
    end
  end

  import key: :number, only: %i[number status customer_id notes]

  batch_action :mark_shipped, label: "Mark as shipped" do |orders|
    "#{orders.where(status: :paid).update_all(status: Order.statuses[:shipped])} paid orders marked as shipped"
  end

  member_action :mark_paid, label: "Mark as paid" do |order|
    order.paid!
    "#{order.number} is paid"
  end

  member_action :cancel, confirm: "Cancel this order?", destructive: true do |order|
    order.cancelled!
    "#{order.number} is cancelled"
  end
end
