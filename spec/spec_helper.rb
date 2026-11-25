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
  config.before(:each, type: :system) do
    driven_by :wibawa_chrome
    # Headless Chrome follows the operating system; without this the suite fails on a machine in dark mode.
    page.driver.browser.page.command("Emulation.setEmulatedMedia", features: [ { name: "prefers-color-scheme", value: "light" } ])
  end
  # The browser keeps localStorage (theme, sidebar rail) from one example to the next unless told otherwise.
  config.after(:each, type: :system) { page.execute_script("try { localStorage.clear() } catch (error) {}") }
  config.after do
    Wibawa.config.authorization = nil
    Wibawa.config.instance_variable_set(:@authenticate, nil)
  end
end
