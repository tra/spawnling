class ActiveRecord::Base

  # method to allow a child process to establish a new connection while letting
  # the parent retain the original connection
  def self.reconnect_in_child(klass=self)
    spec = @@defined_connections[klass.name]
    konn = active_connections[klass.name]
    @@defined_connections.delete_if { |key, value| value == spec }
    active_connections.delete_if { |key, value| value == konn }
    establish_connection(spec ? spec.config : nil)
  end

  # this patch not needed on Rails 2.x and later
  if Rails::VERSION::MAJOR == 1
    # monkey patch to fix threading problems,
    # see: http://dev.rubyonrails.org/ticket/7579
    def self.clear_reloadable_connections!
      if @@allow_concurrency
        # Hash keyed by thread_id in @@active_connections. Hash of hashes.
        @@active_connections.each do |thread_id, conns|
          conns.each do |name, conn|
            if conn.requires_reloading?
              conn.disconnect!
              @@active_connections[thread_id].delete(name)
            end
          end
        end
      else
        # Just one level hash, no concurrency.
        @@active_connections.each do |name, conn|
          if conn.requires_reloading?
            conn.disconnect!
            @@active_connections.delete(name)
          end
        end
      end
    end
  end

end
