module SpawnExtensions
  # FIXME don't know how to tell Spawn to use #add_spawn_proc without extended
  # using extended forces to make methods class methods while this is not very clean
  def self.extended(base)
    Spawn::method proc{ |block| add_spawn_proc(block) }
  end

  # Calls the spawn that was created 
  # 
  # Can be used to keep control over forked processes in your tests
  def call_last_spawn_proc
    spawns = SpawnExtensions.spawn_procs

    raise "No spawn procs left" if spawns.empty?
    
    spawns.pop.call
  end

  private

  def self.spawn_procs
    @@spawn_procs ||= []
  end

  def self.add_spawn_proc(block)
    spawn_procs << block
  end
  
end

# Extend cucumber to take control over spawns
World(SpawnExtensions)