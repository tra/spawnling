require 'spec_helper'

describe Spawnling do
  describe 'defaults' do
    context 'when invalid method' do
      specify {
        expect {
          Spawnling.new(method: :threads) { puts "never" }
        }.to raise_error(
          ArgumentError,
          'method must be :yield, :thread, :fork or respond to method call'
        )
      }
    end
  end

  describe "yields" do
    before(:each) do
      Spawnling::default_options :method => :yield
    end

    it "should work in new block" do
      object = double('object')
      expect(object).to receive(:do_something)
      Spawnling.new do
        object.do_something
      end
    end

    it "should be able to yield directly" do
      expect(spawn!).to eq("hello")
    end
  end

  describe "override" do
    before(:each) do
      Spawnling::default_options :method => proc{ "foo" }
    end

    it "should be able to return a proc" do
      expect(spawn!).to eq("foo")
    end

  end

  describe "delegate to a proc" do
    before(:each) do
      Spawnling::default_options :method => proc{ |block| block }
    end

    it "should be able to return a proc" do
      expect(spawn!).to be_kind_of(Proc)
    end

    it "should be able to return a proc" do
      expect(spawn!.call).to eq("hello")
    end
  end

  describe "thread it" do
    before(:each) do
      Store.reset!
      Spawnling::default_options :method => :thread
    end

    it "should be able to return a proc" do
      expect(Store.flag).to be_falsey
      spawn_flag!
      sleep(0.1) # wait for file to finish writing
      expect(Store.flag).to be_truthy
    end

    it "instance should have a type" do
      instance = Spawnling.new{}
      expect(instance.type).to be(:thread)
    end

    it "instance should have a handle" do
      instance = Spawnling.new{}
      expect(instance.handle).not_to be_nil
    end
  end

  describe "fork it" do
    before(:each) do
      Store.reset!
      Spawnling::default_options :method => :fork
    end

    it "should be able to return a proc" do
      expect(Store.flag).to be_falsey
      spawn_flag!
      sleep(0.1) # wait for file to finish writing
      expect(Store.flag).to be_truthy
    end

    it "instance should have a type" do
      instance = Spawnling.new{}
      expect(instance.type).to be(:fork)
    end

    it "instance should have a handle" do
      instance = Spawnling.new{}
      expect(instance.handle).not_to be_nil
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
