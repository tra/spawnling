Spawnling
=========

[![Gem Version](https://badge.fury.io/rb/spawnling.png)](http://badge.fury.io/rb/spawnling)
[![Build Status](https://travis-ci.org/tra/spawnling.png?branch=master)](https://travis-ci.org/tra/spawnling)
[![Coverage Status](https://coveralls.io/repos/tra/spawnling/badge.png)](https://coveralls.io/r/tra/spawnling)
[![Dependency Status](https://gemnasium.com/tra/spawnling.png)](https://gemnasium.com/tra/spawnling)
[![Code Climate](https://codeclimate.com/github/tra/spawnling.png)](https://codeclimate.com/github/tra/spawnling)

#News

2013-4-15 gem renamed from "spawn-block" (lame) to "spawnling" (awesome).  Sadly the
name "spawn" was taken before I got around to making this into a gem so I decided to
give it a new name and a new home.

Also, now runs with ruby 1.9 (and later).  Because ruby "stole" the name "spawn", this gem
now has been redefined to use "Spawnling.new(&block)" instead of "spawn(&block)".  Other
than that nothing has changed in the basic usage.  Read below for detailed usage.

# Spawnling

This gem provides a 'Spawnling' class to easily fork OR thread long-running sections of
code so that your application can return results to your users more quickly.
It works by creating new database connections in ActiveRecord::Base for the
spawned block so that you don't have to worry about database connections working,
they just do.

The gem also patches ActiveRecord::Base to handle some known bugs when using
threads if you prefer using the threaded model over forking.

## Installation

The name of the gem is "spawnling" (unfortunately somebody took the name "spawn" before
I was able to convert this to a gem).

### git

If you want to live on the latest master branch, add this to your Gemfile,

    gem 'spawnling', :git => 'git://github.com/tra/spawnling'

and use bundler to manage it (bundle install, bundle update).

### rubygem

If you'd rather install from the latest gem,

    gem 'spawnling', '~>2.1'

### configure

Make sure that ActiveRecord reconnects to your database automatically when needed,
for instance put

    production/development:
      ...
      reconnect: true

into your config/database.yml.

## Usage

Here's a simple example of how to demonstrate the spawn plugin.
In one of your controllers, insert this code (after installing the plugin of course):
```ruby
Spawnling.new do
  logger.info("I feel sleepy...")
  sleep 11
  logger.info("Time to wake up!")
end
```
If everything is working correctly, your controller should finish quickly then you'll see
the last log message several seconds later.

If you need to wait for the spawned processes/threads, then pass the objects returned by
spawn to Spawnling.wait(), like this:
```ruby
spawns = []
N.times do |i|
  # spawn N blocks of code
  spawns << Spawnling.new do
    something(i)
  end
end
# wait for all N blocks of code to finish running
Spawnling.wait(spawns)
```
## Options

The options you can pass to spawn are:

<table>
  <tr><th>Option</th><th>Values</th></tr>
  <tr><td>:method</td><td>:fork, :thread, :yield</td></tr>
  <tr><td>:nice</td><td>integer value 0-19, 19 = really nice</td></tr>
  <tr><td>:kill</td><td>boolean value indicating whether the parent should kill the spawned process
   when it exits (only valid when :method => :fork)</td></tr>
  <tr><td>:argv</td><td>string to override the process name</td></tr>
  <tr><td>:detach</td><td>boolean value indicating whether the parent should Process.detach the
   spawned processes. (defaults to true).  You *must* Spawnling.wait or Process.wait if you use this.
   Changing this allows you to wait for the first child to exit instead of waiting for all of them.</td></tr>
</table>

Any option to spawn can be set as a default so that you don't have to pass them in
to every call of spawn.   To configure the spawn default options, add a line to
your configuration file(s) like this:
```ruby
  Spawnling::default_options :method => :thread
```
If you don't set any default options, the :method will default to :fork.  To
specify different values for different environments, add the default_options call to
he appropriate environment file (development.rb, test.rb).   For testing you can set
the default :method to :yield so that the code is run inline.
```ruby
  # in environment.rb
  Spawnling::default_options :method => :fork, :nice => 7
  # in test.rb, will override the environment.rb setting
  Spawnling::default_options :method => :yield
```
This allows you to set your production and development environments to use different
methods according to your needs.

### be nice

If you want your forked child to run at a lower priority than the parent process, pass in
the :nice option like this:
```ruby
Spawnling.new(:nice => 7) do
  do_something_nicely
end
```
### fork me

By default, spawn will use the fork to spawn child processes.  You can configure it to
do threading either by telling the spawn method when you call it or by configuring your
environment.
For example, this is how you can tell spawn to use threading on the call,
```ruby
Spawnling.new(:method => :thread) do
  something
end
```
When you use threaded spawning, make sure that your application is thread-safe. Rails
can be switched to thread-safe mode with (not sure if this is needed anymore)
```ruby
  # Enable threaded mode
  config.threadsafe!
```
in environments/your_environment.rb

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
```ruby
3.times do |i|
 Spawnling.new(:argv => "spawn -#{i}-") do
   something(i)
  end
end
```
then in the shell,
```shell
$ ps -ef | grep spawn
502  2645  2642   0   0:00.01 ttys002    0:00.02 spawn -0-
502  2646  2642   0   0:00.02 ttys002    0:00.02 spawn -1-
502  2647  2642   0   0:00.02 ttys002    0:00.03 spawn -2-
```
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
  be as big as you think... but then again, maybe it's more than you think.  :wink:
- debugging - you can set breakpoints in your threads

## Acknowledgements

This plugin was initially inspired by Scott Persinger's blog post on how to use fork
in rails for background processing (link no longer available).

Further inspiration for the threading implementation came from [Jonathon Rochkind's
blog post](http://bibwild.wordpress.com/2007/08/28/threading-in-rails/) on threading in rails.

Also thanks to all who have helped debug problems and suggest improvements
including:

-  Ahmed Adam, Tristan Schneiter, Scott Haug, Andrew Garfield, Eugene Otto, Dan Sharp,
  Olivier Ruffin, Adrian Duyzer, Cyrille Labesse

-  Garry Tan, Matt Jankowski (Rails 2.2.x fixes), Mina Naguib (Rails 2.3.6 fix)

-  Tim Kadom, Mauricio Marcon Zaffari, Danial Pearce, Hongli Lai, Scott Wadden
  (passenger fixes)

- Will Bryant, James Sanders (memcache fix)

- David Kelso, Richard Hirner, Luke van der Hoeven (gemification and Rails 3 support)

- Jay Caines-Gooby, Eric Stewart (Unicorn fix)

- Dan Sharp for the changes that allow it to work with Ruby 1.9 and later

-  &lt;your name here&gt;

Copyright (c) 2007-present Tom Anderson (tom@squeat.com), see LICENSE
