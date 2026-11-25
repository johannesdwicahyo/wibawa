# Boots a small app on Sprockets (the spec app uses Propshaft) and fetches the
# admin page plus every asset it links to. Run with `bundle exec rake sprockets`.
ENV["RAILS_ENV"] = "test"
ENV["DATABASE_URL"] = "sqlite3::memory:"

require "tmpdir"
require "fileutils"
require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "sprockets/railtie"
require "wibawa"
require "rack/mock"

root = Dir.mktmpdir("wibawa-sprockets")
FileUtils.mkdir_p(File.join(root, "app/assets/config"))
FileUtils.mkdir_p(File.join(root, "app/wibawa"))
File.write(File.join(root, "app/assets/config/manifest.js"), "") # a Sprockets app always has one
File.write(File.join(root, "app/wibawa/things.rb"), "Wibawa.resource Thing\n")

class Thing < ActiveRecord::Base; end

class SprocketsApp < Rails::Application
  config.load_defaults Rails::VERSION::STRING.to_f
  config.eager_load = false
  config.secret_key_base = "test"
  config.hosts.clear
  config.logger = Logger.new(nil)
  config.assets.compile = true
  config.assets.digest = true
end
SprocketsApp.config.root = root
SprocketsApp.initialize!

ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:things) { |t| t.string :name } }
Thing.create!(name: "Kawung")
SprocketsApp.routes.draw { mount Wibawa::Engine, at: "/admin" }

browser = Rack::MockRequest.new(SprocketsApp)
page = browser.get("/admin/things")
abort "Sprockets: the index page answered #{page.status}" unless page.status == 200 && page.body.include?("Kawung")

assets = page.body.scan(%r{(?:href|src)="(/assets/[^"]+)"}).flatten + page.body.scan(%r{url\("(/assets/[^"]+)"\)}).flatten
missing = [%w[wibawa .css], %w[wibawa .js], %w[turbo .js], %w[plus-jakarta-sans-latin- .woff2]].reject do |name, extension|
  assets.any? { |path| path.include?(name) && path.end_with?(extension) }
end
abort "Sprockets: the page does not link #{missing.map(&:join).join(', ')}" if missing.any?

failed = assets.reject do |path|
  response = browser.get(path)
  response.status == 200 && response.body.bytesize > 100
end
abort "Sprockets: assets failed to load: #{failed.join(', ')}" if failed.any?
abort "Sprockets: asset URLs are not fingerprinted" unless assets.all? { |path| path.match?(/-\h{16,}\./) }

puts "Sprockets: page and #{assets.size} assets OK"
FileUtils.rm_rf(root)
