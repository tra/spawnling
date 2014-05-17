require File.dirname(__FILE__) + '/../spec_helper'

describe Spawnling do

  describe "yields" do
    before(:each) do
      Spawnling::default_options :method => :yield
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
  
  def spawn!
    Spawnling.run do
      "hello"
    end
  end
  
end
