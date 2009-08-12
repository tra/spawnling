require 'rubygems'
gem 'rspec'
require 'spec'
require 'active_record'
require 'action_controller'
require 'rails/version'

$:.unshift(File.join(File.dirname(__FILE__), %w[.. lib]))

require 'spawn'
Spec::Runner.configure do |config|

end