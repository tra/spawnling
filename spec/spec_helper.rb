require 'rubygems'
gem 'rspec'
require 'rspec'

$:.unshift(File.join(File.dirname(__FILE__), %w[.. lib]))

require 'store'
if ENV['RAILS']
  require 'rails'
  require 'active_record'
end
ActiveRecord::Base.establish_connection :adapter => :nulldb if defined?(ActiveRecord)

MINIMUM_COVERAGE = 53

if ENV['RAILS']
  class Application < Rails::Application
    config.log_level = :warn
    config.logger = Logger.new(STDOUT)
  end
  Application.initialize!
  Application.config.allow_concurrency = true
end

if ENV['MEMCACHE']
  Application.config.cache_store = :mem_cache_store
end

if ENV['COVERAGE']
  require 'simplecov'
  require 'simplecov-rcov'
  require 'coveralls'
  Coveralls.wear!

  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
    SimpleCov::Formatter::RcovFormatter,
    Coveralls::SimpleCov::Formatter
  ]
  SimpleCov.start do
    add_filter '/vendor/'
    add_filter '/spec/'
    add_filter '/lib/patches.rb'
    add_group 'lib', 'lib'
  end
  SimpleCov.at_exit do
    SimpleCov.result.format!
    percent = SimpleCov.result.covered_percent
    unless percent >= MINIMUM_COVERAGE
      puts "Coverage must be above #{MINIMUM_COVERAGE}%. It is #{"%.2f" % percent}%"
      Kernel.exit(1)
    end
  end
end

require 'spawnling'

