require "rspec/core/rake_task"
require "rubocop/rake_task"

# Unit, request and system specs, against the one-file Rails app in spec/dummy.
RSpec::Core::RakeTask.new(:spec)

desc "Boot the admin on Sprockets and fetch its assets (the spec app uses Propshaft)"
task :sprockets do
  ruby "spec/sprockets_check.rb"
end

RuboCop::RakeTask.new

desc "Run the admin on PostgreSQL with UUID keys (needs a server; DATABASE_URL to point at one)"
task :postgres do
  ruby "spec/postgres_check.rb"
end

# `rake postgres` is not in the default: it needs a database server. CI runs it as a job of its own.
task default: %i[rubocop spec sprockets demo:check]

desc "Run the demo shop admin at http://localhost:3000/admin (PORT=4000 to change)"
task :demo do
  sh "bundle exec rackup demo/config.ru -p #{ENV.fetch('PORT', 3000)}"
end

desc "Time the index page against ActiveAdmin and Administrate (needs: BUNDLE_GEMFILE=benchmark/Gemfile bundle install)"
task :benchmark do
  # Its own bundle and its own process: the other admins are not in Wibawa's Gemfile.
  Bundler.with_unbundled_env { sh({ "BUNDLE_GEMFILE" => "benchmark/Gemfile" }, "bundle exec ruby benchmark/run.rb") }
end

namespace :demo do
  desc "Delete the demo's data; the next `rake demo` seeds it again"
  task :reset do
    rm_rf "demo/tmp"
  end

  desc "Boot the demo in memory and request every kind of page"
  task :check do
    ruby "demo/check.rb"
  end
end
