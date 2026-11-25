Wibawa.dashboard do
  stat("Orders this month") { Order.where(created_at: Time.current.all_month).count }
  stat("Revenue this month", as: :money) { Order.where(status: %i[paid shipped], created_at: Time.current.all_month).sum(:total) }
  stat("Awaiting payment") { Order.pending.count }
  stat("Low stock") { Product.active.low_stock.count }

  table "Latest orders", resource: :orders do
    Order.order(created_at: :desc).limit(8)
  end
end

Wibawa.report :revenue_by_month do
  title "Revenue by month"
  description "Paid and shipped revenue against revenue still waiting for payment, for the last twelve months."
  menu icon: "chart"

  sql <<~SQL
    SELECT strftime('%Y-%m', created_at) AS month,
           SUM(CASE WHEN status IN (1, 2) THEN total ELSE 0 END) AS collected,
           SUM(CASE WHEN status = 0 THEN total ELSE 0 END) AS awaiting_payment
    FROM orders
    WHERE created_at >= date('now', 'start of month', '-11 months')
    GROUP BY month ORDER BY month
  SQL

  column :month
  column :collected, as: :money
  column :awaiting_payment, as: :money
  chart :line, x: :month, y: %i[collected awaiting_payment]
end

Wibawa.report :sales_by_city do
  title "Sales by city"
  description "Where the paid orders come from."
  param :from, as: :date, default: -> { 90.days.ago.to_date }

  sql <<~SQL
    SELECT customers.city, COUNT(*) AS orders, SUM(orders.total) AS revenue
    FROM orders JOIN customers ON customers.id = orders.customer_id
    WHERE orders.status IN (1, 2) AND orders.created_at >= :from
    GROUP BY customers.city ORDER BY revenue DESC
  SQL

  column :city
  column :orders
  column :revenue, as: :money
  chart x: :city, y: :revenue
end

Wibawa.report :best_sellers do
  title "Best sellers"
  description "Units sold per product, cancelled orders left out."

  query do |_params|
    LineItem.joins(:product, :order).where.not(orders: { status: :cancelled })
            .group("products.name").order(Arel.sql("SUM(line_items.quantity) DESC")).sum(:quantity)
  end

  column :product
  column :units
  chart x: :product, y: :units
end

Wibawa.page :stock_check do
  title "Stock check"
  description "Active products with fewer than ten in stock."
  menu group: "Tools", icon: "box"

  content do
    low = Product.active.low_stock.order(:stock)
    if low.none?
      tag.p("Every active product has ten or more in stock.", class: "text-sm text-ink-2")
    else
      tag.ul(class: "divide-y divide-line rounded-card bg-surface text-sm ring-1 ring-line") do
        safe_join(low.map { |product| tag.li(safe_join([ tag.span(product.name), tag.span(product.stock, class: "tabular-nums text-ink-2") ]), class: "flex justify-between px-4 py-2.5") })
      end
    end
  end

  action :restock, label: "Restock low items", confirm: "Add 25 to every low item?" do
    "#{Product.active.low_stock.update_all('stock = stock + 25')} products restocked"
  end
end
