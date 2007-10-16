require 'patches'

ActiveRecord::Base.send :include, Spawn
ActionController::Base.send :include, Spawn
