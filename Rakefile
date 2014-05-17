require "bundler/gem_tasks"

desc 'Default: run coverage.'
task :default => :coverage

require 'rspec/core/rake_task'

desc "Run specs"
RSpec::Core::RakeTask.new do |t|
  t.pattern = "./spec/**/*_spec.rb" # don't need this, it's default.
  # Put spec opts in a file named .rspec in root
end

desc "Generate SimpleCov test coverage and open in your browser"
task :coverage do
  ENV['COVERAGE'] = 'true'
  Rake::Task['spec'].invoke
end
