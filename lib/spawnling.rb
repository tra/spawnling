require 'logger'

class Spawnling
  if defined? ::Rails
    RAILS_1_x = (::Rails::VERSION::MAJOR == 1) unless defined?(RAILS_1_x)
    RAILS_2_2 = ((::Rails::VERSION::MAJOR == 2 && ::Rails::VERSION::MINOR >= 2)) unless defined?(RAILS_2_2)
    RAILS_3_x = (::Rails::VERSION::MAJOR > 2) unless defined?(RAILS_3_x)
  else
    RAILS_1_x = nil
    RAILS_2_2 = nil
    RAILS_3_x = nil
  end

  @@default_options = {
    # default to forking (unless windows or jruby)
    :method => ((RUBY_PLATFORM =~ /(win32|mingw32|java)/) ? :thread : :fork),
    :nice   => nil,
    :kill   => false,
    :argv   => nil,
    :detach => true
  }

  # things to close in child process
  @@resources = []

  # forked children to kill on exit
  @@punks = []

  # in some environments, logger isn't defined
  @@logger = defined?(::Rails) ? ::Rails.logger : ::Logger.new(STDERR)

  def self.logger=(logger)
    @@logger = logger
  end

  attr_accessor :type
  attr_accessor :handle

  # Set the options to use every time spawn is called unless specified
  # otherwise.  For example, in your environment, do something like
  # this:
  #   Spawnling::default_options = {:nice => 5}
  # to default to using the :nice option with a value of 5 on every call.
  # Valid options are:
  #   :method => (:thread | :fork | :yield)
  #   :nice   => nice value of the forked process
  #   :kill   => whether or not the parent process will kill the
  #              spawned child process when the parent exits
  #   :argv   => changes name of the spawned process as seen in ps
  #   :detach => whether or not Process.detach is called for spawned child
  #              processes.  You must wait for children on your own if you
  #              set this to false
  def self.default_options(options = {})
    @@default_options.merge!(options)
    @@logger.info "spawn> default options = #{options.inspect}" if @@logger
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
        @@logger.info "spawn> parent(#{Process.pid}) killing child(#{punk})" if @@logger
        begin
          Process.kill("TERM", punk)
        rescue
        end
      end
    end
    @@punks = []
  end
  # register to kill marked children when parent exits
  at_exit { Spawnling.kill_punks }

  # Spawns a long-running section of code and returns the ID of the spawned process.
  # By default the process will be a forked process.   To use threading, pass
  # :method => :thread or override the default behavior in the environment by setting
  # 'Spawnling::method :thread'.
  def initialize(opts = {}, &block)
    @type, @handle = self.class.run(opts, &block)
  end

  def self.run(opts = {}, &block)
    raise "Must give block of code to be spawned" unless block_given?
    options = @@default_options.merge(symbolize_options(opts))
    # setting options[:method] will override configured value in default_options[:method]
    if options[:method] == :yield
      yield
    elsif options[:method].respond_to?(:call)
      options[:method].call(proc { yield })
    elsif options[:method] == :thread
      # for versions before 2.2, check for allow_concurrency
     if allow_concurrency?
       return :thread, thread_it(options) { yield }
      else
        @@logger.error("spawn(:method=>:thread) only allowed when allow_concurrency=true")
        raise "spawn requires config.active_record.allow_concurrency=true when used with :method=>:thread"
      end
    else
      return :fork, fork_it(options) { yield }
    end
  end

  def self.allow_concurrency?
    return true if RAILS_2_2
    if defined?(ActiveRecord) && ActiveRecord::Base.respond_to?(:allow_concurrency)
      ActiveRecord::Base.allow_concurrency
    elsif defined?(Rails) && Rails.application
      Rails.application.config.allow_concurrency
    else
      true # assume user knows what they are doing
    end
  end

  def self.wait(sids = [])
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
    clean_connections
  end

  protected

  def self.fork_it(options)
    # The problem with rails is that it only has one connection (per class),
    # so when we fork a new process, we need to reconnect.
    @@logger.debug "spawn> parent PID = #{Process.pid}" if @@logger
    child = fork do
      begin
        start = Time.now
        @@logger.debug "spawn> child PID = #{Process.pid}" if @@logger

        # this child has no children of it's own to kill (yet)
        @@punks = []

        # set the nice priority if needed
        Process.setpriority(Process::PRIO_PROCESS, 0, options[:nice]) if options[:nice]

        # disconnect from the listening socket, et al
        Spawnling.close_resources
        if defined?(Rails)
          # get a new database connection so the parent can keep the original one
          ActiveRecord::Base.spawn_reconnect if defined?(ActiveRecord)
          # close the memcache connection so the parent can keep the original one
          Rails.cache.reset if Rails.cache.respond_to?(:reset)
        end

        # set the process name
        $0 = options[:argv] if options[:argv]

        # run the block of code that takes so long
        yield

      rescue => ex
        @@logger.error "spawn> Exception in child[#{Process.pid}] - #{ex.class}: #{ex.message}" if @@logger
        @@logger.error "spawn> " + ex.backtrace.join("\n") if @@logger
      ensure
        begin
          # to be safe, catch errors on closing the connnections too
          ActiveRecord::Base.connection_handler.clear_all_connections! if defined?(ActiveRecord)
        ensure
          @@logger.info "spawn> child[#{Process.pid}] took #{Time.now - start} sec" if @@logger
          # ensure log is flushed since we are using exit!
          @@logger.flush if @@logger && @@logger.respond_to?(:flush)
          # this child might also have children to kill if it called spawn
          Spawnling.kill_punks
          # this form of exit doesn't call at_exit handlers
          exit!(0)
        end
      end
    end

    # detach from child process (parent may still wait for detached process if they wish)
    Process.detach(child) if options[:detach]

    # remove dead children from the target list to avoid memory leaks
    @@punks.delete_if {|punk| !Spawn.alive?(punk)}

    # mark this child for death when this process dies
    if options[:kill]
      @@punks << child
      @@logger.debug "spawn> death row = #{@@punks.inspect}" if @@logger
    end

    # return Spawnling::Id.new(:fork, child)
    return child
  end

  def self.thread_it(options)
    # clean up stale connections from previous threads
    clean_connections
    thr = Thread.new do
      # run the long-running code block
      if defined?(ActiveRecord)
        ActiveRecord::Base.connection_pool.with_connection { yield }
      else
        yield
      end
    end
    thr.priority = -options[:nice] if options[:nice]
    return thr
  end

  def self.clean_connections
    return unless defined? ActiveRecord
    ActiveRecord::Base.verify_active_connections! if ActiveRecord::Base.respond_to?(:verify_active_connections!)
    ActiveRecord::Base.clear_active_connections! if ActiveRecord::Base.respond_to?(:clear_active_connections!)
  end

  # In case we don't have rails, can't call opts.symbolize_keys
  def self.symbolize_options(hash)
    hash.inject({}) do |new_hash, (key, value)|
      new_hash[key.to_sym] = value
      new_hash
    end
  end
end
# backwards compatibility unless someone is using the "other" spawn gem
Spawn = Spawnling unless defined? Spawn

# patches depends on Spawn so require it after the class
require 'patches'
