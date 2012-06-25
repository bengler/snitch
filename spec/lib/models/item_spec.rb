require 'spec_helper'

describe Item do
  it "extracts the uid automatically from attributes hash" do
    Item.create!(:uid => "post:banan.kanon$1")
    Item.first.uid.should == "post:banan.kanon$1"
  end

  it "extracts the uid when creating via find_or_create_by_uid" do
    Item.find_or_create_by_uid("post:banan.kanon$1")
    Item.first.uid.should == "post:banan.kanon$1"
  end
end