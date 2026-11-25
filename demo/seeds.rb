# Made-up data for the demo. The same every time (fixed random seed), with
# dates counted back from today so the charts always have a recent year.
random = Random.new(42)

cities = %w[Yogyakarta Surakarta Pekalongan Cirebon Semarang Jakarta Bandung Surabaya]
names = [ "Sari Wulandari", "Budi Santoso", "Dewi Lestari", "Agus Prasetyo", "Rina Kartika", "Joko Susilo",
         "Maya Anggraini", "Hendra Wijaya", "Putri Rahayu", "Bayu Nugroho", "Indah Permata", "Rudi Hartono",
         "Fitri Handayani", "Eko Saputra", "Wulan Sari", "Dimas Pratama", "Ayu Puspita", "Yoga Kurniawan",
         "Nia Ramadhani", "Arif Setiawan", "Lina Marlina", "Fajar Hidayat", "Citra Kirana", "Galih Permana" ]

customers = names.map do |name|
  Customer.create!(name: name, email: "#{name.downcase.tr(' ', '.')}@example.com", city: cities.sample(random: random),
                   created_at: random.rand(200..400).days.ago)
end

batik = [
  [ "Kain Kawung Sogan", 450_000 ], [ "Kain Parang Rusak", 520_000 ], [ "Kain Mega Mendung", 380_000 ],
  [ "Kain Sekar Jagad", 610_000 ], [ "Kain Truntum", 340_000 ], [ "Kain Sido Mukti", 720_000 ],
  [ "Kemeja Batik Lengan Panjang", 285_000 ], [ "Kemeja Batik Lengan Pendek", 235_000 ], [ "Blus Batik Tulis", 395_000 ],
  [ "Selendang Sutra", 175_000 ], [ "Sarung Batik Cap", 145_000 ], [ "Taplak Meja Batik", 120_000 ],
  [ "Tas Batik Kanvas", 95_000 ], [ "Syal Batik", 85_000 ], [ "Dompet Batik", 65_000 ], [ "Masker Batik", 25_000 ]
]
products = batik.each_with_index.map do |(name, price), index|
  Product.create!(name: name, sku: format("BTK-%03d", index + 1), price: price, stock: random.rand(0..60), active: index != 11)
end

statuses = %i[paid paid paid shipped shipped pending pending cancelled]
240.times do |index|
  # More orders in recent months, so the trend rises.
  placed = (random.rand**1.6 * 365).round.days.ago - random.rand(0..86_000).seconds
  status = placed > 6.days.ago ? %i[pending pending paid].sample(random: random) : statuses.sample(random: random)
  order = Order.new(number: format("TK-%05d", 1001 + index), customer: customers.sample(random: random), status: status,
                    notes: (index % 9).zero? ? "Bungkus kado, kirim sebelum akhir pekan." : nil, created_at: placed, updated_at: placed)
  products.sample(random.rand(1..4), random: random).each_with_index do |product, position|
    order.line_items.build(product: product, quantity: random.rand(1..3), unit_price: product.price, position: position + 1)
  end
  order.save!
end

puts "Seeded #{Customer.count} customers, #{Product.count} products and #{Order.count} orders."
