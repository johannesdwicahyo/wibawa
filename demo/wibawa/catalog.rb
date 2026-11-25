Wibawa.resource Customer do
  menu group: "Sales", icon: "users", priority: 2

  search :name, :email
  filter :city, as: :select, collection: -> { Customer.distinct.order(:city).pluck(:city) }
  filter :created_at, as: :date_range

  index sort: { name: :asc } do
    column :name
    column :email, as: :email
    column :city
    column("Orders") { |customer| customer.orders.size }
    column :created_at, label: "Customer since", as: :date
    actions
  end

  form do
    field :name
    field :email
    field :city
  end

  import key: :email
end

Wibawa.resource Product do
  menu group: "Catalog", icon: "tag"

  scope :all, default: true
  scope :active
  scope :low_stock

  search :name, :sku
  filter :active
  filter :price, as: :number_range
  filter :stock, as: :number_range

  index density: :compact, sort: { name: :asc } do
    column :sku
    column :name
    column :price, as: :money
    column :stock
    column :active
    actions
  end

  form do
    field :name
    field :sku
    field :price
    field :stock
    field :active
  end

  import key: :sku
end
