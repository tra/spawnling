require 'spec_helper'

describe Spawnling do

  describe "yields" do
    before(:each) do
      Spawnling::default_options :method => :yield
    end

    it "should work in new block" do
      object = double('object')
      object.should_receive(:do_something)
      Spawnling.new do
        object.do_something
      end
    end

    it "should be able to yield directly" do
      spawn!.should == "hello"
    end
  end

  describe "override" do
    before(:each) do
      Spawnling::default_options :method => proc{ "foo" }
    end

    it "should be able to return a proc" do
      spawn!.should == "foo"
    end

  end

  describe "delegate to a proc" do
    before(:each) do
      Spawnling::default_options :method => proc{ |block| block }
    end

    it "should be able to return a proc" do
      spawn!.should be_kind_of(Proc)
    end

    it "should be able to return a proc" do
      spawn!.call.should == "hello"
    end
  end

  describe "thread it" do
    before(:each) do
      Store.reset!
      Spawnling::default_options :method => :thread
    end

    it "should be able to return a proc" do
      Store.flag.should be_falsey
      spawn_flag!
      sleep(0.1) # wait for file to finish writing
      Store.flag.should be_truthy
    end

    it "instance should have a type" do
      instance = Spawnling.new{}
      instance.type.should be(:thread)
    end

    it "instance should have a handle" do
      instance = Spawnling.new{}
      instance.handle.should_not be_nil
    end
  end

  describe "fork it" do
    before(:each) do
      Store.reset!
      Spawnling::default_options :method => :fork
    end

    it "should be able to return a proc" do
      Store.flag.should be_falsey
      spawn_flag!
      sleep(0.1) # wait for file to finish writing
      Store.flag.should be_truthy
    end

    it "instance should have a type" do
      instance = Spawnling.new{}
      instance.type.should be(:fork)
    end

    it "instance should have a handle" do
      instance = Spawnling.new{}
      instance.handle.should_not be_nil
    end
  end

  def spawn!
    Spawnling.run do
      "hello"
    end
  end

  def spawn_flag!
    Spawnling.new do
      Store.flag!
    end
  end

end
