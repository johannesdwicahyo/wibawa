require_relative "dummy/app"
require "rspec/rails"
require "mcp"

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.after do
    Wibawa.config.authorization = nil
    Wibawa.config.instance_variable_set(:@authenticate, nil)
  end
end
