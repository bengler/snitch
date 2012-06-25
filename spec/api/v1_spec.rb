require 'spec_helper'

describe 'API v1' do
  include Rack::Test::Methods

  def app
    SnitchV1
  end

  context "with a logged in god" do
    before :each do
      Pebblebed::Connector.any_instance.stub(:checkpoint).and_return(DeepStruct.wrap(:me => {:id => 1337, :god => true, :realm => 'rock_and_roll'}))
    end

    it "lets me report a decision on an unreported item" do 
      uid = "thing:thang$thong"
      post "/items/#{uid}/decision", :item => {:decision => 'kept'}
      item = Item.first
      item.uid.should eq uid
      item.report_count.should eq 0
      item.decision.should eq 'kept'
      item.decision_at.should_not be_nil
      item.decider.should eq 1337
    end

    it "gives me a list of unprocessed items" do
      10.times do |i|
        post "/reports/thing:thang$#{i}"
      end

      post "/reports/thing:thang.thong$13666"
      
      get "/items", :path => "thang"
      result = JSON.parse(last_response.body)
      oids = result['items'].map do |record|
        record['item']['uid'][/\$\d*$/][1..-1]
      end
      oids.should eq ["9", "8", "7", "6", "5", "4", "3", "2", "1", "0"]

      # Register a decision and see the item is removed from the list
      post "/items/thing:thang$5/decision", :item => {:decision => 'removed'}
      get "/items", :path => "thang"
      result = JSON.parse(last_response.body)
      oids = result['items'].map do |record|
        record['item']['uid'][/\$\d*$/][1..-1]
      end
      oids.should eq ["9", "8", "7", "6", "4", "3", "2", "1", "0"] # < with '5' removed
    end

    it "supports querying items by uid" do
      post "/reports/klass1:apdm.calendar$1"
      post "/reports/klass2:apdm.calendar$2"
      post "/reports/klass2:apdm.blogs$3"

      get "/items/*:apdm.*"
      JSON.parse(last_response.body)['items'].size.should eq 3

      get "/items/*:mittap.*"
      JSON.parse(last_response.body)['items'].size.should eq 0

      get "/items/klass2:*"
      JSON.parse(last_response.body)['items'].size.should eq 2

      get "/items/klass2:apdm.blogs"
      JSON.parse(last_response.body)['items'].size.should eq 1
    end

    it "only accepts valid decisions" do
      post "/items/item:of$somesort/decision", :item => {:decision => 'kept'}
      last_response.status.should eq 200
      post "/items/item:of$othersort/decision", :item => {:decision => 'removed'}
      last_response.status.should eq 200
      post "/items/item:of$thirdkind/decision", :item => {:decision => 'beloved'}
      last_response.status.should eq 400
    end

  end

  context "with a logged in user" do
    before :each do
      Pebblebed::Connector.any_instance.stub(:checkpoint).and_return(DeepStruct.wrap(:me => {:id => 1337, :god => false, :realm => 'rock_and_roll'}))
    end

    it "accepts a report of objectionable content" do
      uid = 'post:realm$1'
      post "/reports/#{uid}"
      report = Report.first
      report.uid.should eq uid
      report.reporter.should eq 1337
      item = Item.first
      item.realm.should eq "realm"
      item.uid.should eq uid
      item.report_count.should eq 1
    end

    it "quietly rejects multiple reports from same user of same content" do
      uid = 'post:realm$1'
      post "/reports/#{uid}"
      post "/reports/#{uid}"
      last_response.status.should eq 200
      Item.count.should eq 1
      item = Item.first
      item.report_count.should eq 1
    end

    it "counts distinct reports distinctly" do
      Report.create!(:uid => "dings:blah$1", :reporter => 1)
      Report.create!(:uid => "dings:blah$1", :reporter => 2)
      Report.create!(:uid => "dings:blah$1", :reporter => 3)
      Report.create!(:uid => "dings:blah$2", :reporter => 1)
      post "/reports/dings:blah$1"
      Item.find_by_uid("dings:blah$1").report_count.should eq 4
      Item.find_by_uid("dings:blah$2").report_count.should eq 1
    end

    it "won't give me any items 'cause I'm nobody" do
      get "/items?path=dingo"
      last_response.status.should eq 403
    end

    it "won't let me report a decision 'cause I'm nobody" do
      post "/items/thing:thang$thong/decision", :decision => 'kept'
      last_response.status.should eq 403
    end

  end

  describe "with no current user" do
    before :each do
      Pebblebed::Connector.any_instance.stub(:checkpoint).and_return(DeepStruct.wrap(:me => {}))
    end

    it "accepts anonymous reports" do
      uid = 'post:realm$1'
      post "/reports/#{uid}"
      post "/reports/#{uid}"
      post "/reports/#{uid}"
      report = Report.first
      report.reporter.should be_nil
      report.item.uid.should eq uid
      report.item.report_count.should eq 3
    end

    it "won't give me any items 'cause I'm nobody" do
      get "/items?path=dingo"
      last_response.status.should eq 403
    end

    it "won't let me report a decision 'cause I'm nobody" do
      post "/items/thing:thang$thong/decision", :decision => 'kept'
      last_response.status.should eq 403
    end

  end

end
