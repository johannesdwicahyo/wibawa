require "rake/testtask"
require "rspec/core/rake_task"

# Unit tests for the DSL (no Rails needed).
Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.pattern = "test/**/*_test.rb"
end

# Request specs against the one-file Rails app in spec/dummy.
RSpec::Core::RakeTask.new(:spec)

task default: %i[test spec]
