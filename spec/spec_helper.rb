require_relative "dummy/app"
require "rspec/rails"
require "mcp"
require "capybara/cuprite"

# System specs drive headless Chrome over CDP. The server runs in this
# process, so it shares the in-memory database and the test transaction.
Capybara.register_driver(:wibawa_chrome) do |app|
  Capybara::Cuprite::Driver.new(app, window_size: [ 1280, 900 ], process_timeout: 30,
                                     browser_options: ENV["CI"] ? { "no-sandbox" => nil } : {})
end
Capybara.server = :puma, { Silent: true }

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.before(:each, type: :system) { driven_by :wibawa_chrome }
  config.after do
    Wibawa.config.authorization = nil
    Wibawa.config.instance_variable_set(:@authenticate, nil)
  end
end
