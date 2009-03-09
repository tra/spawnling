# see activerecord/lib/active_record/connection_adaptors/abstract/connection_specification.rb
class ActiveRecord::Base
  # reconnect without disconnecting
  if Spawn::RAILS_2_2
    def self.spawn_reconnect(klass=self)
      @@connection_handler = ActiveRecord::ConnectionAdapters::ConnectionHandler.new
      establish_connection
    end
  else
    def self.spawn_reconnect(klass=self)
      spec = @@defined_connections[klass.name]
      konn = active_connections[klass.name]
      # remove from internal arrays before calling establish_connection so that
      # the connection isn't disconnected when it calls AR::Base.remove_connection
      @@defined_connections.delete_if { |key, value| value == spec }
      active_connections.delete_if { |key, value| value == konn }
      establish_connection(spec ? spec.config : nil)
    end
  end

  # this patch not needed on Rails 2.x and later
  if Spawn::RAILS_1_x
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

# see mongrel/lib/mongrel.rb
# it's possible that this is not defined if you're running outside of mongrel
# examples: ./script/runner or ./script/console
if defined? Mongrel::HttpServer
  class Mongrel::HttpServer
    # redefine Montrel::HttpServer::process_client so that we can intercept
    # the socket that is being used so Spawn can close it upon forking
    alias_method :orig_process_client, :process_client
    def process_client(client)
      Spawn.resources_to_close(client, @socket)
      orig_process_client(client)
    end
  end
end

# Patch for work with passenger < 2.1.0
if defined? Passenger::Railz::RequestHandler
  class Passenger::Railz::RequestHandler
    alias_method :orig_process_request, :process_request
    def process_request(headers, input, output)
      Spawn.resources_to_close(input, output)
      orig_process_request(headers, input, output)
    end
  end
end

# Patch for work with passenger >= 2.1.0
if defined? PhusionPassenger::Railz::RequestHandler
  class PhusionPassenger::Railz::RequestHandler
    alias_method :orig_process_request, :process_request
    def process_request(headers, input, output)
      Spawn.resources_to_close(input, output)
      orig_process_request(headers, input, output)
    end
  end
end
