ActiveAdmin.register Customer
ActiveAdmin.register Order do
  includes :customer
  config.per_page = [ 50, 500 ]
  config.sort_order = "id_desc"
  index do
    selectable_column
    id_column
    column :number
    column :customer
    column :status
    column(:total) { |order| number_to_currency(order.total) }
    column :created_at
    actions
  end
end
