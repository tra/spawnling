require 'patches'

ActiveRecord::Base.send :include, Spawn
ActionController::Base.send :include, Spawn
ActiveRecord::Observer.send :include, Spawn
Enumerable::Array.send :include, Spawn
Enumerable::Range.send :include, Spawn
