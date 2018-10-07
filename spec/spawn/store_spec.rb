require 'spec_helper'

describe Store do
  it 'should flag/unflag' do
    Store.reset!
    expect(Store.flag).to be_falsey
    Store.flag!
    expect(Store.flag).to be_truthy
    Store.reset!
    expect(Store.flag).to be_falsey
  end
end
