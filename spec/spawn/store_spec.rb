require 'spec_helper'

describe Store do
  it 'should flag/unflag' do
    Store.reset!
    Store.flag.should be_false
    Store.flag!
    Store.flag.should be_true
    Store.reset!
    Store.flag.should be_false
  end
end
