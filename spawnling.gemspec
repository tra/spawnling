# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'spawnling/version'

Gem::Specification.new do |s|
  s.name          = "spawnling"
  s.version       = Spawnling::VERSION

  s.authors       = ['Tom Anderson', 'Michael Noack']
  s.email         = ['tom@squeat.com', 'michael+spawnling@noack.com.au']

  s.homepage      = %q{http://github.com/tra/spawnling}
  s.license       = "MIT"
  s.summary       = %q{Easily fork OR thread long-running sections of code in Ruby}
  s.description   = %q{This plugin provides a 'Spawnling' class to easily fork OR
thread long-running sections of code so that your application can return
results to your users more quickly.  This plugin works by creating new database
connections in ActiveRecord::Base for the spawned block.

The plugin also patches ActiveRecord::Base to handle some known bugs when using
threads (see lib/patches.rb).}

  s.files         = `git ls-files`.split($/)
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]

  s.add_development_dependency 'bundler'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec', '~> 2.0'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'simplecov-rcov'
  s.add_development_dependency 'coveralls'
  s.add_development_dependency 'rails'
  s.add_development_dependency 'activerecord-nulldb-adapter'
  s.add_development_dependency 'dalli'
end
