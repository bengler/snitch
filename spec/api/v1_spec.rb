require 'spec_helper'
require 'pebblebed'
require 'pebblebed/rspec_helper'

describe 'API v1' do
  include Rack::Test::Methods
  include Pebblebed::RSpecHelper
  def app
    SnitchV1
  end

  let(:checkpoint) {
    checkpoint = stub
    checkpoint.stub!(:service_url => 'http://example.com')
    checkpoint
  }

  let(:group_user) {
    DeepStruct.wrap(:identity => {:realm => 'testrealm', :id => 1, :god => false})
  }
  let(:access) {
    DeepStruct.wrap(:allowed => true)
  }
  let(:access_denied) {
    DeepStruct.wrap(:allowed => false)
  }
  context "with a logged in user that is allowed through checkpoint psm2 callback" do

    before(:each) do
      user!
      checkpoint.should_receive(:get).at_least(1).times.with("/identities/me").and_return(group_user)
      Pebblebed::Connector.any_instance.stub(:checkpoint => checkpoint)
    end

    it "lets me report a decision on an unreported item" do
      checkpoint.should_receive(:get).at_least(1).times.with("/callbacks/allowed/create/thing:testrealm$thong").and_return(access)
      uid = "thing:testrealm$thong"
      post "/items/#{uid}/actions", :action => {:kind => 'kept'}
      item = Item.first
      item.uid.should eq uid
      item.report_count.should eq 0
      item.decision.should eq 'kept'
      item.action_at.should_not be_nil
      item.decider.should eq 1
    end

    it "gives me a list of unprocessed items" do
      checkpoint.should_receive(:get).at_least(1).times.with("/callbacks/allowed/create/thing:testrealm$5").and_return(access)
      10.times do |i|
        post "/reports/thing:testrealm$#{i}"
      end

      post "/reports/thing:testrealm.thong$13666"

      get "/items", :path => "testrealm"
      result = JSON.parse(last_response.body)
      oids = result['items'].map do |record|
        record['item']['uid'][/\$\d*$/][1..-1]
      end
      oids.should eq ["9", "8", "7", "6", "5", "4", "3", "2", "1", "0"]

      # Register a decision and see the item is removed from the list
      post "/items/thing:testrealm$5/actions", :action => {:kind => 'removed'}
      get "/items", :path => "testrealm"
      result = JSON.parse(last_response.body)
      oids = result['items'].map do |record|
        record['item']['uid'][/\$\d*$/][1..-1]
      end
      oids.should eq ["9", "8", "7", "6", "4", "3", "2", "1", "0"] # < with '5' removed
    end

    it "supports sorting on created_at in both orders" do
      Timecop.travel(Time.parse("2012-09-20T09:52:09+02:00"))
      3.times do |i|
        Timecop.travel(i.days.ago) do
          post "/reports/thing:testrealm$#{i}"
        end
      end

      get "/items", :path => "testrealm", :sort_by => "created_at", :order => "desc"
      result = JSON.parse(last_response.body)
      dates = result['items'].map do |record|
        record['item']['created_at']
      end
      dates.should == ["2012-09-20T09:52:09+02:00", "2012-09-19T09:52:09+02:00", "2012-09-18T09:52:09+02:00"]

      get "/items", :path => "testrealm", :sort_by => "created_at", :order => "asc"
      result = JSON.parse(last_response.body)
      dates = result['items'].map do |record|
        record['item']['created_at']
      end
      dates.should == ["2012-09-18T09:52:09+02:00", "2012-09-19T09:52:09+02:00", "2012-09-20T09:52:09+02:00"]
    end

    it "supports sorting on updated_at in both orders" do
      Timecop.travel(Time.parse("2012-09-20T09:52:09+02:00"))
      3.times do |i|
        Timecop.travel(i.days.ago) do
          post "/reports/thing:testrealm$#{i}"
        end
      end
      # Update first post
      Timecop.travel(Time.parse("2012-10-20T09:52:09+02:00")) do
        i = Item.first
        i.report_count = 2
        i.save!
      end
      get "/items", :path => "testrealm", :sort_by => "updated_at", :order => "desc"
      result = JSON.parse(last_response.body)
      dates = result['items'].map do |record|
        record['item']['updated_at']
      end
      dates.should == ["2012-10-20T09:52:09+02:00", "2012-09-19T09:52:09+02:00", "2012-09-18T09:52:09+02:00"]

      get "/items", :path => "testrealm", :sort_by => "updated_at", :order => "asc"
      result = JSON.parse(last_response.body)
      dates = result['items'].map do |record|
        record['item']['updated_at']
      end
      dates.should == ["2012-09-18T09:52:09+02:00", "2012-09-19T09:52:09+02:00", "2012-10-20T09:52:09+02:00"]
    end

    it "supports sorting on action_at in both orders" do
      checkpoint.should_receive(:get).with("/callbacks/allowed/create/thing:testrealm$0").and_return(access)
      checkpoint.should_receive(:get).with("/callbacks/allowed/create/thing:testrealm$1").and_return(access)
      checkpoint.should_receive(:get).with("/callbacks/allowed/create/thing:testrealm$2").and_return(access)
      Timecop.travel(Time.parse("2012-09-20T09:52:09+02:00"))
      3.times do |i|
        Timecop.travel(i.days.ago) do
          post "/reports/thing:testrealm$#{i}"
        end
      end
      # Register an action
      Timecop.travel(Time.parse("2012-10-22T09:52:09+02:00")) do
        post "/items/thing:testrealm$1/actions", :action => {:kind => 'seen'}
      end
      Timecop.travel(Time.parse("2012-11-15T09:52:09+02:00")) do
        post "/items/thing:testrealm$2/actions", :action => {:kind => 'seen'}
      end
      Timecop.travel(Time.parse("2012-12-01T09:52:09+02:00")) do
        post "/items/thing:testrealm$0/actions", :action => {:kind => 'seen'}
      end

      get "/items", :path => "testrealm", :sort_by => "action_at", :order => "desc"
      result = JSON.parse(last_response.body)
      dates = result['items'].map do |record|
        record['item']['action_at']
      end
      dates.should == ["2012-12-01T08:52:09+01:00", "2012-11-15T08:52:09+01:00", "2012-10-22T09:52:09+02:00"]

      get "/items", :path => "testrealm", :sort_by => "action_at", :order => "asc"
      result = JSON.parse(last_response.body)
      dates = result['items'].map do |record|
        record['item']['action_at']
      end
      dates.should == ["2012-10-22T09:52:09+02:00", "2012-11-15T08:52:09+01:00", "2012-12-01T08:52:09+01:00"]
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

    it "supports querying items by uids (multiple) with a null placeholder for missing items" do
      post "/reports/klass1:apdm.calendar$1"
      post "/reports/klass2:apdm.calendar$2"
      post "/reports/klass2:apdm.blogs$3"

      get "/items/klass1:apdm.calendar$1,klass2:apdm.calendar$2,klass2:apdm.blogs$3,klass2:apdm.blogs$4"
      JSON.parse(last_response.body)['items'].size.should eq 4
      JSON.parse(last_response.body)['items'].last['uid'].should be_nil
      JSON.parse(last_response.body)['items'].select {|i| i['item']['uid'] == nil}.size.should == 1
    end

    it "only accepts valid actions" do
      checkpoint.should_receive(:get).with("/callbacks/allowed/create/item:testrealm$somesort").and_return(access)
      checkpoint.should_receive(:get).with("/callbacks/allowed/create/item:testrealm$othersort").and_return(access)
      checkpoint.should_receive(:get).with("/callbacks/allowed/create/item:testrealm$thirdkind").and_return(access)
      post "/items/item:testrealm$somesort/actions", :action => {:kind => 'kept'}
      last_response.status.should eq 200
      post "/items/item:testrealm$othersort/actions", :action => {:kind => 'removed'}
      last_response.status.should eq 200
      post "/items/item:testrealm$thirdkind/actions", :action => {:kind => 'beloved'}
      last_response.status.should eq 400
      Action.count.should == 2
    end

    it "denies access accross realms" do
      checkpoint.should_not_receive(:get).at_least(1).times.with("/callbacks/allowed/create/item:foo$somesort").and_return(access_denied)
      post "/items/item:foo$somesort/actions", :action => {:kind => 'kept'}
      last_response.status.should eq 403
    end

    it "provides a lists of recent actions" do
      checkpoint.should_receive(:get).at_least(1).times.with("/callbacks/allowed/create/item:testrealm$one").and_return(access)
      checkpoint.should_receive(:get).at_least(1).times.with("/callbacks/allowed/create/otherklass:testrealm$two").and_return(access)
      checkpoint.should_receive(:get).at_least(1).times.with("/callbacks/allowed/create/item:testrealm.subitem$three").and_return(access)
      post "/items/item:testrealm$one/actions", :action => {:kind => 'edited'}
      post "/items/item:testrealm$one/actions", :action => {:kind => 'edited'}
      post "/items/item:testrealm.subitem$three/actions", :action => {:kind => 'edited'}
      post "/items/otherklass:testrealm$two/actions", :action => {:kind => 'edited'}

      get "/items/*:*/actions"
      JSON.parse(last_response.body)['actions'].size.should == 4
      get "/items/item:*/actions"
      JSON.parse(last_response.body)['actions'].size.should == 3
      get "/items/*:testrealm/actions"
      JSON.parse(last_response.body)['actions'].size.should == 3
      get "/items/item:testrealm.*/actions"
      JSON.parse(last_response.body)['actions'].size.should == 3
      get "/items/item:testrealm.*$one/actions"
      JSON.parse(last_response.body)['actions'].size.should == 2
    end

  end

  context "with a logged in user" do
    before(:each) do
      user!
    end

    it "accepts a report of objectionable content" do
      uid = 'post:realm$1'
      post "/reports/#{uid}"
      report = Report.first
      report.uid.should eq uid
      report.reporter.should eq 1
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
      Report.create!(:uid => "dings:blah$1", :reporter => 4)
      Report.create!(:uid => "dings:blah$1", :reporter => 2)
      Report.create!(:uid => "dings:blah$1", :reporter => 3)
      Report.create!(:uid => "dings:blah$2", :reporter => 4)
      post "/reports/dings:blah$1"
      Item.find_by_uid("dings:blah$1").report_count.should eq 4
      Item.find_by_uid("dings:blah$2").report_count.should eq 1
    end

    it "won't let me report a decision 'cause I'm nobody" do
      post "/items/thing:testrealm$thong/actions", :action => {:kind => 'kept'}
      last_response.status.should eq 403
    end

  end

  describe "with no current user" do

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

    it "won't let me report a decision 'cause I'm nobody" do
      post "/items/thing:testrealm$thong/actions", :action => {:kind => 'kept'}
      last_response.status.should eq 403
    end

  end

end
