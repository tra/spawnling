# -*- encoding: utf-8 -*-
Gem::Specification.new do |s|
  s.name        = "spawn"
  s.version     = "1.0.1.1"
  s.platform    = Gem::Platform::RUBY
  s.homepage    = "https://github.com/tra/spawn"
  s.authors     = ["Tom Anderson"]
  s.email       = ['tom@squeat.com']
  s.summary     = 'Easily fork/thread long-running code blocks within a rails application'
  s.description = %q{
    This plugin provides a 'spawn' method to easily fork OR thread long-running sections of
    code so that your application can return results to your users more quickly.
    This plugin works by creating new database connections in ActiveRecord::Base for the
    spawned block.

    The plugin also patches ActiveRecord::Base to handle some known bugs when using 
    threads (see lib/patches.rb).
  }
  s.required_rubygems_version = '>= 1.3.7'
  s.files                     = Dir.glob("lib/**/*") + %w(LICENSE README.markdown init.rb)
  s.require_path              = "lib"

  s.add_development_dependency 'rails', "=2.3.10"
  s.add_runtime_dependency 'rails', "=2.3.10"
end
