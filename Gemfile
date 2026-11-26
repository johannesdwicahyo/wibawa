source "https://rubygems.org"

gemspec

# CI runs the suite against each supported Rails: RAILS_VERSION=7.2 bundle install
rails = ENV["RAILS_VERSION"] && "~> #{ENV['RAILS_VERSION']}.0"
%w[railties activerecord actionpack].each { |name| gem name, rails } if rails
# ActiveSupport 8.0.4 passes JSON an option that json 3 removed (every page fails; nothing to do
# with Wibawa). Held back for 7.2 as well, where json 3 was not tried.
gem "json", "< 3" if rails && ENV["RAILS_VERSION"].to_f < 8.1

gem "rake"
gem "rspec-rails"
gem "rubocop-rails-omakase", require: false
gem "sqlite3"
gem "mcp"

# System specs: a real browser against spec/dummy (Chrome over CDP, no driver binary).
gem "capybara"
gem "cuprite"
gem "puma"
gem "propshaft"

# What the README promises to work with, so the specs can prove it.
gem "activestorage", *rails
gem "actiontext", *rails
gem "pundit"
gem "rails-i18n" # Rails' own strings (dates, validation messages) in Indonesian
gem "action_policy"
gem "paper_trail" # a record's page lists its versions
gem "audited"     # or its audits
gem "sprockets-rails", require: false # only spec/sprockets_check.rb loads it
