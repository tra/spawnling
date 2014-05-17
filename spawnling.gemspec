# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name          = "spawnling"
  s.version       = "2.1.1"

  s.authors       = ['Tom Anderson']
  s.email         = ['tom@squeat.com']

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
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'coveralls'
  s.add_development_dependency 'rails'
end
