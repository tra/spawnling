require File.dirname(__FILE__) + '/../../test_helper/test_helper'

class SpawnTest < ActiveSupport::TestCase
  context "Enumerable extensions" do
    setup do
      @all = [1,2,3,4,5]
      FileUtils.rm_f "/tmp/should_iterate_in_groups"
    end

    should "should iterate over all eventually if no exceptions" do
      results = []
      
      # we use method => :thread in testing so that the modification of 'results' is visible to our process
      @all.each_in_parallel_groups_of(2, :method=>:thread) do |individual|
        results << individual
      end
      
      assert_equal @all.sort, results.sort
    end
    
    should "groups wait for the previous group to finish, but run simultaneously within a group" do
      first_sec = Time.now.sec
      @all.each_in_parallel_groups_of(2, :method => :fork) do |individual|
        File.open("/tmp/should_iterate_in_groups", "a") do |f|
          f.puts Time.now.sec
        end
        sleep 1
      end

      results = File.new("/tmp/should_iterate_in_groups").readlines.map(&:chomp).map(&:to_i)
      assert_equal @all.length, results.length
      
      # Running one group per second, there should be 3 unique seconds recorded
      assert_equal 3.ceil, results.uniq.length 
      
      # 2 items ran in the first second
      assert_equal 2, results.select{|r| r==first_sec}.length
      
    end
    
  end
end
