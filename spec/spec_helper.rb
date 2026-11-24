require_relative "dummy/app"
require "rspec/rails"
require "mcp"

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.after { Wibawa.config.authorization = nil }
end
