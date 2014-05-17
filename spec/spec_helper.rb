require 'rubygems'
gem 'rspec'
require 'rspec'

$:.unshift(File.join(File.dirname(__FILE__), %w[.. lib]))

require 'spawnling'
Spec::Runner.configure do |config|

end
