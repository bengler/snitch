require 'spec_helper'

describe Item do

  it "creates by external_uid" do
    Item.create!(:external_uid => "post:banan.kanon$1")
    expect(Item.first.external_uid).to eq "post:banan.kanon$1"
    expect(Item.first.uid).to eq "snitchitem.post:banan.kanon$1"
  end

  it "finds by external_uid" do
    Item.create!(:external_uid => "post:banan.kanon$1")
    Item.find_or_create_by_external_uid("post:banan.kanon$1")
    expect(Item.first.external_uid).to eq "post:banan.kanon$1"
    expect(Item.first.uid).to eq "snitchitem.post:banan.kanon$1"
  end

  it "finds by wildcard uid" do
    Item.create!(:external_uid => "post:banan.kanon$1")
    expect(Item.by_wildcard_external_uid("post:banan.kanon$1").first.uid).to eq "snitchitem.post:banan.kanon$1"
    expect(Item.first.external_uid).to eq "post:banan.kanon$1"
    expect(Item.first.uid).to eq "snitchitem.post:banan.kanon$1"
  end

  it "fixes the uid when external_uid changes" do
    item = Item.create!(:external_uid => 'post:banan.kanon$1')
    item.external_uid = 'post:banan.kanon.rakett$1'
    expect(item.uid).to eq 'snitchitem.post:banan.kanon.rakett$1'
  end

end
