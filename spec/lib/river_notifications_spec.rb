require 'spec_helper'

describe RiverNotifications do

  context 'publishes on report create' do

    before :each do
      Pebblebed::River.any_instance.should_receive(:publish).with(hash_including(:event => :create)).once
    end

    it 'works' do
      item = Item.create!(:external_uid => "post:banan.kanon$1")
      Report.create!(:uid => item.external_uid)
    end

  end

end
