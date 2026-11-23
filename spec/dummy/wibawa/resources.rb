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
