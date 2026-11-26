# Times the orders index page of each admin, in one process, with no network.
#   BUNDLE_GEMFILE=benchmark/Gemfile bundle exec ruby benchmark/run.rb
# RUNS=200 changes how many timed requests each case gets (default 100).
require_relative "app"
require "rack/mock"
require "zlib"

RUNS = Integer(ENV.fetch("RUNS", 100))
WARMUP = 10

ADMINS = {
  "Wibawa #{Wibawa::VERSION}" => "/wibawa/orders?per_page=%d",
  "ActiveAdmin #{ActiveAdmin::VERSION}" => "/activeadmin/orders?per_page=%d",
  "Administrate #{Administrate::VERSION}" => "/administrate/orders?per_page=%d"
}.freeze

queries = 0
ActiveSupport::Notifications.subscribe("sql.active_record") { |event| queries += 1 unless event.payload[:name] == "SCHEMA" }

def get(path) = Rack::MockRequest.new(Rails.application).get(path, "HTTP_HOST" => "localhost")

def median(values) = values.sort[values.size / 2]

results = []
[ 50, 500 ].each do |rows|
  ADMINS.each do |name, path|
    url = format(path, rows)
    response = get(url)
    abort "#{name}: HTTP #{response.status} for #{url}\n#{response.body[0, 2000]}" unless response.status == 200
    shown = response.body.scan(/ORD-\d{5}/).uniq.size
    abort "#{name}: #{shown} orders on the page, expected #{rows}" unless shown == rows

    WARMUP.times { get(url) }
    queries = 0
    get(url)
    per_request_queries = queries

    GC.start
    before = GC.stat(:total_allocated_objects)
    get(url)
    allocated = GC.stat(:total_allocated_objects) - before

    times = Array.new(RUNS) do
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      get(url)
      (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
    end
    results << { rows: rows, name: name, ms: median(times), p95: times.sort[(times.size * 0.95).floor], objects: allocated,
                 queries: per_request_queries, kb: response.body.bytesize / 1024.0, gzip: Zlib.gzip(response.body).bytesize / 1024.0 }
  end
end

puts "Ruby #{RUBY_VERSION}, Rails #{Rails.version}, SQLite in memory, #{RUNS} requests per case after #{WARMUP} to warm up"
puts
puts "| Rows | Admin | Median | 95th percentile | Objects allocated | SQL queries | HTML | HTML, gzipped |"
puts "| --- | --- | --- | --- | --- | --- | --- | --- |"
results.each do |r|
  puts format("| %d | %s | %.1f ms | %.1f ms | %s | %d | %.0f KB | %.0f KB |", r[:rows], r[:name], r[:ms], r[:p95],
              r[:objects].to_s.reverse.scan(/\d{1,3}/).join(",").reverse, r[:queries], r[:kb], r[:gzip])
end
