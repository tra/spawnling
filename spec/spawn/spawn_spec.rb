require File.dirname(__FILE__) + '/../spec_helper'

describe Spawn do

  describe "yields" do
    before(:each) do
      Spawn::method :yield
      define_spawned
    end
  
    it "should be able to yield directly" do
      Spawned.hello.should == "hello"
    end
  end
  
  describe "override" do
    before(:each) do
      Spawn::method(proc{ "foo" })
      define_spawned
    end
    
    it "should be able to return a proc" do
      Spawned.hello.should == "foo"
    end
    
  end
  
  describe "delegate to a proc" do
    before(:each) do
      Spawn::method( proc{ |block| block  })
      define_spawned
    end
    
    it "should be able to return a proc" do
      Spawned.hello.should be_kind_of(Proc)
    end
  
    it "should be able to return a proc" do
      Spawned.hello.call.should == "hello"
    end
    
  end
  
  after(:each) do
    Object.send(:remove_const, :Spawned)
  end
  
  def define_spawned
    cls = Class.new do
      extend Spawn
    
      def self.hello
        spawn do
          "hello"
        end
      end
      
    end
    
    Object.const_set :Spawned, cls
  end
  
end