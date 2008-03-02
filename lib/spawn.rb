module Spawn

  # default to forking (unless windows or jruby)
  @@method = (RUBY_PLATFORM =~ /(win32|java)/) ? :thread : :fork

  # add calls to this in your environment.rb to set your configuration, for example,
  # to use forking everywhere except your 'development' environment:
  #   Spawn::method :fork
  #   Spawn::method :thread, 'development'
  def self.method(method, env = nil)
    if !env || env == RAILS_ENV
      @@method = method
    end
  end
  
  # Spawns a long-running section of code and returns the ID of the spawned process.
  # By default the process will be a forked process.   To use threading, pass
  # :method => :thread or override the default behavior in the environment by setting
  # 'Spawn::method :thread'.
  def spawn(options = {})
    options.symbolize_keys!
    # setting options[:method] will override configured value in @@method
    if options[:method] == :yield || @@method == :yield
      yield
    elsif options[:method] == :thread || (options[:method] == nil && @@method == :thread)
      if ActiveRecord::Base.allow_concurrency
        thread_it(options) { yield }
      else
        logger.error("spawn(:method=>:thread) only allowed when allow_concurrency=true")
        raise "spawn requires config.active_record.allow_concurrency=true when used with :method=>:thread"
      end
    else
      fork_it(options) { yield }
    end
  end
  
  def wait(sids = [])
    # wait for all threads and/or forks
    sids.to_a.each do |sid|
      if sid.type == :thread
        sid.handle.join()
      else
        begin
          Process.wait(sid.handle)
        rescue
          # if the process is already done, ignore the error
        end
      end
    end
    # clean up connections from expired threads
    ActiveRecord::Base.verify_active_connections!()
  end
  
  class SpawnId
    attr_accessor :type
    attr_accessor :handle
    def initialize(t, h)
      self.type = t
      self.handle = h
    end
  end

  protected
  def fork_it(options)
    # The problem with rails is that it only has one connection (per class),
    # so when we fork a new process, we need to reconnect.
    child = fork do
      # call the method we added in patches.rb to allow the child to get a new connection
      # without messing with the parent's connection
      ActiveRecord::Base.reconnect_in_child
      begin
        # run the block of code that takes so long
        yield
      ensure
        ActiveRecord::Base.connection.disconnect!
        ActiveRecord::Base.remove_connection
      end
      # this form of exit doesn't call at_exit handlers
      exit!
    end
    # detach from child process (parent may still wait for detached process if they wish)
    Process.detach(child)
    # reconnect in the parent process
    return SpawnId.new(:fork, child)
  end

  def thread_it(options)
    # clean up stale connections from previous threads
    ActiveRecord::Base.verify_active_connections!()
    thr = Thread.new do
      # run the long-running code block
      yield
    end
    return SpawnId.new(:thread, thr)
  end

end
