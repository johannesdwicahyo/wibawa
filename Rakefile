require "rake/testtask"
require "rspec/core/rake_task"

# Unit tests for the DSL (no Rails needed).
Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.pattern = "test/**/*_test.rb"
end

# Request specs against the one-file Rails app in spec/dummy.
RSpec::Core::RakeTask.new(:spec)

task default: %i[test spec demo:check]

desc "Run the demo shop admin at http://localhost:3000/admin (PORT=4000 to change)"
task :demo do
  sh "bundle exec rackup demo/config.ru -p #{ENV.fetch('PORT', 3000)}"
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
