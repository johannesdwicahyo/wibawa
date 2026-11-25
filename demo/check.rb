# Boots the demo on an in-memory database and asks for every kind of page,
# so the demo cannot quietly break. Run with `bundle exec rake demo:check`.
ENV["DATABASE_URL"] = "sqlite3::memory:"
require_relative "app"
require "rack/mock"

Rails.logger.level = :fatal
paths = %w[/admin /admin/orders /admin/orders/1 /admin/orders/1/edit /admin/orders/new /admin/customers /admin/products
           /admin/reports/revenue_by_month /admin/reports/sales_by_city /admin/reports/best_sellers
           /admin/pages/stock_check /admin/audit_log /admin/orders.csv /admin/-/search?q=sari]
failed = paths.reject { |path| Rack::MockRequest.new(Demo::Application).get(path).status == 200 }
abort "Demo pages failed: #{failed.join(', ')}" if failed.any?
puts "Demo: #{paths.size} pages OK"
