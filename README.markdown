# Spawn

This plugin provides a 'spawn' method to easily fork OR thread long-running sections of
code so that your application can return results to your users more quickly.
This plugin works by creating new database connections in ActiveRecord::Base for the
spawned block.

The plugin also patches ActiveRecord::Base to handle some known bugs when using 
threads (see lib/patches.rb).

## Installation

To install the plugin from the master branch (recommended).

    script/plugin install git://github.com/tra/spawn.git

If you want to install the plugin from the 'edge' branch (latest development):

    script/plugin install git://github.com/tra/spawn.git -r edge

If you are unfortunate enough to be stuck on Rails 1.x, then it is recommended you
stick with v1.0 of this plugin (Rails 1.x won't be supported in future versions but
it might still work if you're lucky).   To install this version:

    script/plugin install git://github.com/tra/spawn.git -r master:v1.0

## Usage

Here's a simple example of how to demonstrate the spawn plugin.
In one of your controllers, insert this code (after installing the plugin of course):

    spawn do
       logger.info("I feel sleepy...")
       sleep 11
       logger.info("Time to wake up!")
     end

If everything is working correctly, your controller should finish quickly then you'll see
the last log message several seconds later.

If you need to wait for the spawned processes/threads, then pass the objects returned by
spawn to Spawn::wait(), like this:

    N.times do |i|
      # spawn N blocks of code
      spawn_ids[i] = spawn do
        something(i)
      end
    end
    # wait for all N blocks of code to finish running
    wait(spawn_ids)

## Options

The options you can pass to spawn are:

<table>
  <tr><th>Option</th><th>Values</th></tr>
  <tr><td>:method</td><td>:fork, :thread, :yield</td></tr>
  <tr><td>:nice</td><td>integer value 0-19, 19 = really nice</td></tr>
  <tr><td>:kill</td><td>boolean value indicating whether the parent should kill the spawned process
   when it exits (only valid when :method => :fork)</td></tr>
  <tr><td>:argv</td><td>string to override the process name</td></tr>
</table>

Any option to spawn can be set as a default so that you don't have to pass them in
to every call of spawn.   To configure the spawn default options, add a line to
your configuration file(s) like this: 

    Spawn::default_options {:method => :thread}

If you don't set any default options, the :method will default to :fork.  To
specify different values for different environments, add the default_options call to
he appropriate environment file (development.rb, test.rb).   For testing you can set
the default :method to :yield so that the code is run inline.

    # in environment.rb
    Spawn::method :method => :fork, :nice => 7
    # in test.rb, will override the environment.rb setting
    Spawn::method :method => :yield

This allows you to set your production and development environments to use different
methods according to your needs.

### be nice

If you want your forked child to run at a lower priority than the parent process, pass in
the :nice option like this:

    spawn(:nice => 7) do
      do_something_nicely
    end

### fork me

By default, spawn will use the fork to spawn child processes.  You can configure it to
do threading either by telling the spawn method when you call it or by configuring your
environment.
For example, this is how you can tell spawn to use threading on the call,

    spawn(:method => :thread) do
      something
    end
  
For older versions of Rails (1.x), when using the :thread setting, spawn will check to
make sure that you have set allow_concurrency=true in your configuration.   If you
want this setting then put this line in one of your environment config files: 

    config.active_record.allow_concurrency = true

If it is not set, then spawn will raise an exception.

### kill or be killed

Depending on your application, you may want the children processes to go away when
the parent  process exits.   By default spawn lets the children live after the
parent dies.   But you can tell it to kill the children by setting the :kill option
to true.

### a process by any other name

If you'd like to be able to identify which processes are spawned by looking at the
output of ps then set the :argv option with a string of your choice.
You should then be able to see this string as the process name when
listing the running processes (ps).

For example, if you do something like this,

    3.times do |i|
      spawn(:argv => "spawn -#{i}-") do
        something(i)
      end
    end

then in the shell,

    $ ps -ef | grep spawn
    502  2645  2642   0   0:00.01 ttys002    0:00.02 spawn -0-
    502  2646  2642   0   0:00.02 ttys002    0:00.02 spawn -1-
    502  2647  2642   0   0:00.02 ttys002    0:00.03 spawn -2-

The length of the process name may be limited by your OS so you might want to experiment
to see how long it can be (it may be limited by the length of the original process name).

## Forking vs. Threading

There are several tradeoffs for using threading vs. forking.   Forking was chosen as the
default primarily because it requires no configuration to get it working out of the box.

Forking advantages:

- more reliable? - the ActiveRecord code is generally not deemed to be thread-safe.
  Even though spawn attempts to patch known problems with the threaded implementation,
  there are no guarantees.  Forking is heavier but should be fairly reliable.
- keep running - this could also be a disadvantage, but you may find you want to fork
  off a process that could have a life longer than its parent.  For example, maybe you
  want to restart your server without killing the spawned processes.
  We don't necessarily condone this (i.e. haven't tried it) but it's technically possible.
- easier - forking works out of the box with spawn, threading requires you set
  allow_concurrency=true (for older versions of Rails).
  Also, beware of automatic reloading of classes in development
  mode (config.cache_classes = false).

Threading advantages:
- less filling - threads take less resources... how much less?  it depends.   Some 
  flavors of Unix are pretty efficient at forking so the threading advantage may not
  be as big as you think... but then again, maybe it's more than you think.  ;-)
- debugging - you can set breakpoints in your threads

## Acknowledgements

This plugin was initially inspired by Scott Persinger's blog post on how to use fork
in rails for background processing.
    http://geekblog.vodpod.com/?p=26

Further inspiration for the threading implementation came from Jonathon Rochkind's
blog post on threading in rails.
    http://bibwild.wordpress.com/2007/08/28/threading-in-rails/
    
Also thanks to all who have helped debug problems and suggest improvements
including:

-  Ahmed Adam, Tristan Schneiter, Scott Haug, Andrew Garfield, Eugene Otto, Dan Sharp,
  Olivier Ruffin, Adrian Duyzer, Cyrille Labesse

-  Garry Tan, Matt Jankowski (Rails 2.2.x fixes), Mina Naguib (Rails 2.3.6 fix)

-  Tim Kadom, Mauricio Marcon Zaffari, Danial Pearce, Hongli Lai, Scott Wadden
  (passenger fixes)

-  &lt;your name here&gt;

Copyright (c) 2007-present Tom Anderson (tom@squeat.com), see LICENSE
