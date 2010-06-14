module Spawn
  RAILS_1_x = (::Rails::VERSION::MAJOR == 1) unless defined?(RAILS_1_x)
  RAILS_2_2 = (::Rails::VERSION::MAJOR > 2 || (::Rails::VERSION::MAJOR == 2 && ::Rails::VERSION::MINOR >= 2)) unless defined?(RAILS_2_2)

  @@default_options = {
    # default to forking (unless windows or jruby)
    :method => ((RUBY_PLATFORM =~ /(win32|java)/) ? :thread : :fork),
    :nice   => nil,
    :kill   => false,
    :argv   => nil
  }
  
  # things to close in child process
  @@resources = []
  # in some environments, logger isn't defined
  @@logger = defined?(RAILS_DEFAULT_LOGGER) ? RAILS_DEFAULT_LOGGER : Logger.new(STDERR)
  # forked children to kill on exit
  @@punks = []

  # Set the options to use every time spawn is called unless specified
  # otherwise.  For example, in your environment, do something like
  # this:
  #   Spawn::default_options = {:nice => 5}
  # to default to using the :nice option with a value of 5 on every call.
  # Valid options are:
  #   :method => (:thread | :fork | :yield)
  #   :nice   => nice value of the forked process
  #   :kill   => whether or not the parent process will kill the
  #              spawned child process when the parent exits
  #   :argv   => changes name of the spawned process as seen in ps
  def self.default_options(options = {})
    @@default_options.merge!(options)
    @@logger.info "spawn> default options = #{options.inspect}"
  end

  # @deprecated - please use Spawn::default_options(:method => ) instead
  # add calls to this in your environment.rb to set your configuration, for example,
  # to use forking everywhere except your 'development' environment:
  #   Spawn::method :fork
  #   Spawn::method :thread, 'development'
  def self.method(method, env = nil)
    @@logger.warn "spawn> please use Spawn::default_options(:method => #{method}) instead of Spawn::method"
    if !env || env == RAILS_ENV
      default_options :method => method
    end
  end

  # set the resources to disconnect from in the child process (when forking)
  def self.resources_to_close(*resources)
    @@resources = resources
  end

  # close all the resources added by calls to resource_to_close
  def self.close_resources
    @@resources.each do |resource|
      resource.close if resource && resource.respond_to?(:close) && !resource.closed?
    end
    # in case somebody spawns recursively
    @@resources.clear
  end
  
  def self.alive?(pid)
    begin
      Process::kill 0, pid
      # if the process is alive then kill won't throw an exception
      true
    rescue Errno::ESRCH
      false
    end
  end
  
  def self.kill_punks
    @@punks.each do |punk|
      if alive?(punk)
        @@logger.info "spawn> parent(#{Process.pid}) killing child(#{punk})"
        begin
          Process.kill("TERM", punk)
        rescue
        end
      end
    end
    @@punks = []
  end
  # register to kill marked children when parent exits
  at_exit {kill_punks}

  # Spawns a long-running section of code and returns the ID of the spawned process.
  # By default the process will be a forked process.   To use threading, pass
  # :method => :thread or override the default behavior in the environment by setting
  # 'Spawn::method :thread'.
  def spawn(opts = {})
    options = @@default_options.merge(opts.symbolize_keys)
    # setting options[:method] will override configured value in default_options[:method]
    if options[:method] == :yield
      yield
    elsif options[:method] == :thread
      # for versions before 2.2, check for allow_concurrency
      if RAILS_2_2 || ActiveRecord::Base.allow_concurrency
        thread_it(options) { yield }
      else
        @@logger.error("spawn(:method=>:thread) only allowed when allow_concurrency=true")
        raise "spawn requires config.active_record.allow_concurrency=true when used with :method=>:thread"
      end
    else
      fork_it(options) { yield }
    end
  end
  
  def wait(sids = [])
    # wait for all threads and/or forks (if a single sid passed in, convert to array first)
    Array(sids).each do |sid|
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
    @@logger.debug "spawn> parent PID = #{Process.pid}"
    child = fork do
      begin
        start = Time.now
        @@logger.debug "spawn> child PID = #{Process.pid}"

        # this child has no children of it's own to kill (yet)
        @@punks = []

        # set the nice priority if needed
        Process.setpriority(Process::PRIO_PROCESS, 0, options[:nice]) if options[:nice]

        # disconnect from the listening socket, et al
        Spawn.close_resources
        # get a new connection so the parent can keep the original one
        ActiveRecord::Base.spawn_reconnect
        
        # set the process name
        $0 = options[:argv] if options[:argv]

        # run the block of code that takes so long
        yield

      rescue => ex
        @@logger.error "spawn> Exception in child[#{Process.pid}] - #{ex.class}: #{ex.message}"
      ensure
        begin
          # to be safe, catch errors on closing the connnections too
          if RAILS_2_2
            ActiveRecord::Base.connection_handler.clear_all_connections!
          else
            ActiveRecord::Base.connection.disconnect!
            ActiveRecord::Base.remove_connection
          end
        ensure
          @@logger.info "spawn> child[#{Process.pid}] took #{Time.now - start} sec"
          # ensure log is flushed since we are using exit!
          @@logger.flush if @@logger.respond_to?(:flush)
          # this child might also have children to kill if it called spawn
          Spawn::kill_punks
          # this form of exit doesn't call at_exit handlers
          exit!(0)
        end
      end
    end

    # detach from child process (parent may still wait for detached process if they wish)
    Process.detach(child)

    # remove dead children from the target list to avoid memory leaks
    @@punks.delete_if {|punk| !Spawn::alive?(punk)}

    # mark this child for death when this process dies
    if options[:kill]
      @@punks << child
      @@logger.debug "spawn> death row = #{@@punks.inspect}"
    end

    return SpawnId.new(:fork, child)
  end

  def thread_it(options)
    # clean up stale connections from previous threads
    ActiveRecord::Base.verify_active_connections!()
    thr = Thread.new do
      # run the long-running code block
      yield
    end
    thr.priority = -options[:nice] if options[:nice]
    return SpawnId.new(:thread, thr)
  end

end
