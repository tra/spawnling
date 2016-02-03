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

require 'support/coverage_loader'

require 'spawnling'
