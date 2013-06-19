require 'spec_helper'

describe RiverNotifications do

  context 'publishes on item create' do

    before :each do
      Pebblebed::River.any_instance.should_receive(:publish).with(hash_including(:event => :create)).once
    end

    it 'works' do
      Item.create!(:external_uid => "post:banan.kanon$1")
    end

  end

  context 'publishes on item update' do

    before :each do
      Pebblebed::River.any_instance.should_receive(:publish).twice do |arg|
        arg[:uid].should eq 'snitchitem.post:banan.kanon$2' if arg[:event] == :create
        arg[:uid].should eq 'snitchitem.post:banan.kanon$20' if arg[:event] == :update
      end
    end

    it 'works' do
      item = Item.create!(:external_uid => "post:banan.kanon$2")
      item.external_uid = 'post:banan.kanon$20'
      item.save!
    end

  end

  context 'publishes on item delete' do

    before :each do
      Pebblebed::River.any_instance.should_receive(:publish).twice do |arg|
        arg[:uid].should eq 'snitchitem.post:banan.kanon$3' if arg[:event] == :create
        arg[:attributes][:decision].should eq 'removed' if arg[:event] == :delete
      end
    end

    it 'works' do
      item = Item.create!(:external_uid => "post:banan.kanon$3")
      item.decision = 'removed'
      item.save!
    end

  end

end