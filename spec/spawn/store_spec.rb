require 'spec_helper'

describe Store do
  it 'should flag/unflag' do
    Store.reset!
    Store.flag.should be_falsey
    Store.flag!
    Store.flag.should be_truthy
    Store.reset!
    Store.flag.should be_falsey
  end
end
