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
    double(:service_url => 'http://example.com')
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
      checkpoint.should_receive(:post).at_least(1).times.with("/callbacks/allowed/create/thing:testrealm$thong").and_return(access)
      uid = "thing:testrealm$thong"
      post "/items/#{uid}/actions", :action => {:kind => 'kept'}
      item = Item.first
      item.uid.should eq "snitchitem.#{uid}"
      item.external_uid.should eq uid
      item.report_count.should eq 0
      item.decision.should eq 'kept'
      item.action_at.should_not be_nil
      item.decider.should eq 1
    end

    it "lets me report a decision on a wildcard path" do
      uid = "thing:testrealm.calendar.*"
      Item.create!(:external_uid => "thing:testrealm.calendar.facebook$123")
      Item.create!(:external_uid => "thing:testrealm.calendar.origo$321")
      Item.create!(:external_uid => "thing:testrealm.foo.bar$123")
      checkpoint.should_receive(:post).at_least(1).times.with("/callbacks/allowed/create/#{uid}").and_return(access)
      post "/items/#{uid}/actions", :action => {:kind => 'seen'}
      last_response.status.should == 200
      result = JSON.parse(last_response.body)['actions'].size.should eq 2
      Item.find_by_external_uid("thing:testrealm.calendar.facebook$123").seen.should eq true
      Item.find_by_external_uid("thing:testrealm.calendar.origo$321").seen.should eq true
      Item.find_by_external_uid("thing:testrealm.foo.bar$123").seen.should eq false
    end

    it "gives me a list of unprocessed items" do
      checkpoint.should_receive(:post).at_least(1).times.with("/callbacks/allowed/create/thing:testrealm$5").and_return(access)
      10.times do |i|
        Item.create!(:external_uid => "thing:testrealm$#{i}")
      end
      10.times do |i|
        post "/reports/thing:testrealm$#{i}"
      end

      post "/reports/thing:testrealm.thong$13666"
      get "/items", :path => "testrealm"
      result = JSON.parse(last_response.body)
      oids = result['items'].map do |record|
        record['item']['external_uid'][/\$\d*$/][1..-1]
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
      Timecop.travel(Time.parse("2012-05-20T09:52:09+02:00"))
      3.times do |i|
        Timecop.travel(i.days.ago) do
          Item.create!(:external_uid => "thing:testrealm$#{i}")
          post "/reports/thing:testrealm$#{i}"
        end
      end

      get "/items", :path => "testrealm", :sort_by => "created_at", :order => "desc"
      result = JSON.parse(last_response.body)
      dates = result['items'].map do |record|
        record['item']['created_at']
      end
      dates.should == ["2012-05-20T11:52:09+02:00", "2012-05-19T11:52:09+02:00", "2012-05-18T11:52:09+02:00"]

      get "/items", :path => "testrealm", :sort_by => "created_at", :order => "asc"
      result = JSON.parse(last_response.body)
      dates = result['items'].map do |record|
        record['item']['created_at']
      end
      dates.should == ["2012-05-18T11:52:09+02:00", "2012-05-19T11:52:09+02:00", "2012-05-20T11:52:09+02:00"]
    end

    it "supports sorting on updated_at in both orders" do
      Timecop.travel(Time.parse("2012-05-20T09:52:09+02:00"))
      3.times do |i|
        Timecop.travel(i.days.ago) do
          Item.create!(:external_uid => "thing:testrealm$#{i}")
          post "/reports/thing:testrealm$#{i}"
        end
      end
      # Update first post
      Timecop.travel(Time.parse("2012-05-20T09:52:09+02:00")) do
        i = Item.first
        i.report_count = 2
        i.save!
      end
      get "/items", :path => "testrealm", :sort_by => "updated_at", :order => "desc"
      result = JSON.parse(last_response.body)
      dates = result['items'].map do |record|
        record['item']['updated_at']
      end
      dates.should == ["2012-05-20T11:52:09+02:00", "2012-05-19T11:52:09+02:00", "2012-05-18T11:52:09+02:00"]

      get "/items", :path => "testrealm", :sort_by => "updated_at", :order => "asc"
      result = JSON.parse(last_response.body)
      dates = result['items'].map do |record|
        record['item']['updated_at']
      end
      dates.should == ["2012-05-18T11:52:09+02:00", "2012-05-19T11:52:09+02:00", "2012-05-20T11:52:09+02:00"]
    end

    it "supports sorting on action_at in both orders" do
      checkpoint.should_receive(:post).with("/callbacks/allowed/create/thing:testrealm$0").and_return(access)
      checkpoint.should_receive(:post).with("/callbacks/allowed/create/thing:testrealm$1").and_return(access)
      checkpoint.should_receive(:post).with("/callbacks/allowed/create/thing:testrealm$2").and_return(access)
      Timecop.travel(Time.parse("2012-09-20T09:52:09+02:00"))
      3.times do |i|
        Timecop.travel(i.days.ago) do
          Item.create!(:external_uid => "thing:testrealm$#{i}")
          post "/reports/thing:testrealm$#{i}"
        end
      end
      # Register an action
      Timecop.travel(Time.parse("2012-05-20T09:52:09+02:00")) do
        post "/items/thing:testrealm$1/actions", :action => {:kind => 'seen'}
      end
      Timecop.travel(Time.parse("2012-07-20T09:52:09+02:00")) do
        post "/items/thing:testrealm$2/actions", :action => {:kind => 'seen'}
      end
      Timecop.travel(Time.parse("2012-08-20T09:52:09+02:00")) do
        post "/items/thing:testrealm$0/actions", :action => {:kind => 'seen'}
      end

      get "/items", :path => "testrealm", :sort_by => "action_at", :order => "desc"
      result = JSON.parse(last_response.body)
      dates = result['items'].map do |record|
        record['item']['action_at']
      end
      dates.should == ["2012-08-20T11:52:09+02:00", "2012-07-20T11:52:09+02:00", "2012-05-20T11:52:09+02:00"]

      get "/items", :path => "testrealm", :sort_by => "action_at", :order => "asc"
      result = JSON.parse(last_response.body)
      dates = result['items'].map do |record|
        record['item']['action_at']
      end
      dates.should == ["2012-05-20T11:52:09+02:00", "2012-07-20T11:52:09+02:00", "2012-08-20T11:52:09+02:00"]
    end

    it "supports querying items by uid" do

      Item.create!(:external_uid => "klass1:apdm.calendar$1")
      post "/reports/klass1:apdm.calendar$1"
      Item.create!(:external_uid => "klass2:apdm.calendar$2")
      post "/reports/klass2:apdm.calendar$2"
      Item.create!(:external_uid => "klass2:apdm.blogs$3")
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
      Item.create!(:external_uid => "klass1:apdm.calendar$1")
      post "/reports/klass1:apdm.calendar$1"
      Item.create!(:external_uid => "klass2:apdm.calendar$2")
      post "/reports/klass2:apdm.calendar$2"
      Item.create!(:external_uid => "klass2:apdm.blogs$3")
      post "/reports/klass2:apdm.blogs$3"

      get "/items/klass1:apdm.calendar$1,klass2:apdm.calendar$2,klass2:apdm.blogs$3,klass2:apdm.blogs$4"
      JSON.parse(last_response.body)['items'].size.should eq 4
      JSON.parse(last_response.body)['items'].last['uid'].should be_nil
      JSON.parse(last_response.body)['items'].select {|i| i['item']['uid'] == nil}.size.should == 1
    end

    it "supports querying items by species query" do
      Item.create!(:external_uid => "post.foo:apdm.calendar$1")
      post "/reports/post.foo:apdm.calendar$1"
      Item.create!(:external_uid => "post.bar:apdm.calendar$2")
      post "/reports/post.bar:apdm.calendar$2"
      Item.create!(:external_uid => "post.bogus:apdm.blogs$3")
      post "/reports/post.bogus:apdm.blogs$3"
      Item.create!(:external_uid => "foo.bogus:apdm.blogs$3")
      post "/reports/foo.bogus:apdm.blogs$3"

      Item.create!(:external_uid => "bim:apdm.blogs$3")
      post "/reports/bim:apdm.blogs$3"
      Item.create!(:external_uid => "bam:apdm.blogs$3")
      post "/reports/bam:apdm.blogs$3"

      get "/items/post.foo%7Cbar:apdm.*"
      JSON.parse(last_response.body)['items'].size.should eq 2

      get "/items/post.foo%7Cbar%7Cbogus:apdm.*"
      JSON.parse(last_response.body)['items'].size.should eq 3

      get "/items/bim%7Cbam:apdm.*"
      JSON.parse(last_response.body)['items'].size.should eq 2

    end

    it "only accepts valid actions" do
      checkpoint.should_receive(:post).with("/callbacks/allowed/create/item:testrealm$somesort").and_return(access)
      checkpoint.should_receive(:post).with("/callbacks/allowed/create/item:testrealm$othersort").and_return(access)
      checkpoint.should_receive(:post).with("/callbacks/allowed/create/item:testrealm$thirdkind").and_return(access)
      post "/items/item:testrealm$somesort/actions", :action => {:kind => 'kept'}
      last_response.status.should eq 200
      post "/items/item:testrealm$othersort/actions", :action => {:kind => 'removed'}
      last_response.status.should eq 200
      post "/items/item:testrealm$thirdkind/actions", :action => {:kind => 'beloved'}
      last_response.status.should eq 400
      Action.count.should == 2
    end

    it "denies access accross realms" do
      checkpoint.should_not_receive(:post).at_least(1).times.with("/callbacks/allowed/create/item:foo$somesort").and_return(access_denied)
      post "/items/item:foo$somesort/actions", :action => {:kind => 'kept'}
      last_response.status.should eq 403
    end

    it "provides a lists of recent actions" do
      checkpoint.should_receive(:post).at_least(1).times.with("/callbacks/allowed/create/item:testrealm$one").and_return(access)
      checkpoint.should_receive(:post).at_least(1).times.with("/callbacks/allowed/create/otherklass:testrealm$two").and_return(access)
      checkpoint.should_receive(:post).at_least(1).times.with("/callbacks/allowed/create/item:testrealm.subitem$three").and_return(access)
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

    it "provides a paginated list of reports for the given item" do
      uid = "item:testrealm$one"
      Item.create!(:external_uid => uid)
      post "/reports/#{uid}"
      post "/reports/#{uid}", :kind => 'offensive', :comment => 'Harsh language!'
      post "/reports/#{uid}", :kind => 'offensive', :comment => 'Simply intolerable!'
      post "/reports/#{uid}", :kind => 'falsehood', :comment => 'What a load of ...'
      checkpoint.should_receive(:post).at_least(1).times.
        with("/callbacks/allowed/create/#{uid}").and_return(access)
      get "/items/#{uid}/reports"
      last_response.status.should eq 200
      hash = JSON.parse(last_response.body)
      hash.should have_key 'pagination'
      hash.should have_key 'reports'
      hash['reports'].size.should eq 4
      hash['reports'].each do |report_hash|
        report = report_hash['report']
        report['uid'].should eq "snitchreport.#{uid}"
        report['external_uid'].should eq uid
        report['reporter'].should_not be_nil
        report['created_at'].should_not be_nil
        report.should have_key 'kind'
        report.should have_key 'comment'
      end
    end

    it "provides an empty list of reports for an item Snitch doesn't know about" do
      uid = "item:testrealm$fourtytwo"
      checkpoint.should_receive(:post).at_least(1).times.
        with("/callbacks/allowed/create/#{uid}").and_return(access)
      get "/items/#{uid}/reports"
      last_response.status.should eq 200
      hash = JSON.parse(last_response.body)
      hash.should have_key 'reports'
      hash['reports'].size.should eq 0
    end
  end

  context "with a logged in user" do
    before(:each) do
      user!
    end

    it "accepts a report of objectionable content" do
      uid = 'post:realm$1'
      Item.create!(:external_uid => uid)
      post "/reports/#{uid}"
      report = Report.first
      report.item.external_uid.should eq uid
      report.reporter.should eq 1
      report.kind.should be_nil
      report.comment.should be_nil
      item = Item.first
      item.realm.should eq "realm"
      item.external_uid.should eq uid
      item.report_count.should eq 1
    end

    it "accepts a report of objectionable content with kind and comment" do
      uid = 'post:realm$1'
      Item.create!(:external_uid => uid)
      post "/reports/#{uid}", :kind => 'bollox', :comment => 'Hogwash!'
      report = Report.first
      report.uid.should eq "snitchreport.#{uid}"
      report.reporter.should eq 1
      report.kind.should eq 'bollox'
      report.comment.should eq 'Hogwash!'
      item = Item.first
      item.realm.should eq "realm"
      item.uid.should eq "snitchitem.#{uid}"
      item.external_uid.should eq uid
      item.report_count.should eq 1
    end

    it "quietly rejects multiple reports from same user of same content with no kind" do
      uid = 'post:realm$1'
      Item.create!(:external_uid => uid)
      post "/reports/#{uid}"
      post "/reports/#{uid}"
      last_response.status.should eq 200
      Item.count.should eq 1
      item = Item.first
      item.report_count.should eq 1
    end

    it "accepts multiple reports of same kind from same user of same content" do
      uid = 'post:realm$1'
      Item.create!(:external_uid => uid)
      post "/reports/#{uid}", :kind => 'foo'
      post "/reports/#{uid}", :kind => 'foo'
      last_response.status.should eq 200
      Item.count.should eq 1
      item = Item.first
      item.report_count.should eq 2
    end

    it "accepts multiple reports of distinct kinds from same user of same content" do
      uid = 'post:realm$1'
      Item.create!(:external_uid => uid)
      post "/reports/#{uid}", :kind => 'foo'
      post "/reports/#{uid}", :kind => 'bar'
      last_response.status.should eq 200
      Item.count.should eq 1
      item = Item.first
      item.report_count.should eq 2
    end

    it "disallows posting reports to a item that doesn't exist" do
      uid = 'post:realm$1'
      post "/reports/#{uid}", :kind => 'foo'
      last_response.status.should eq 404
    end

    it "counts distinct reports distinctly" do
      Report.create!(:uid => "dings:blah$1", :reporter => 4)
      Report.create!(:uid => "dings:blah$1", :reporter => 2)
      Report.create!(:uid => "dings:blah$1", :reporter => 3)
      Report.create!(:uid => "dings:blah$2", :reporter => 4)
      post "/reports/dings:blah$1"
      Item.find_by_external_uid("dings:blah$1").report_count.should eq 4
      Item.find_by_external_uid("dings:blah$2").report_count.should eq 1
    end

    it "won't let me report a decision 'cause I'm no admin" do
      uid = "thing:testrealm$thong2"
      Item.create!(:external_uid => uid)
      checkpoint.should_receive(:post).at_least(1).times.with("/callbacks/allowed/create/#{uid}").and_return(access_denied)
      checkpoint.should_receive(:get).at_least(1).times.with("/identities/me").and_return(group_user)
      Pebblebed::Connector.any_instance.stub(:checkpoint => checkpoint)
      post "/items/#{uid}/actions", :action => {:kind => 'kept'}
      last_response.status.should eq 403
    end

    it "sets the realm correctly" do
      uid = 'post:realm$1'
      Item.create!(:external_uid => uid)
      post "/reports/#{uid}", :kind => 'foo'
      Item.count.should eq 1
      item = Item.first
      item.realm.should eq 'realm'
      item.read_attribute(:realm).should eq 'realm'
    end

  end

  describe "with no current user" do

    it "accepts anonymous reports" do
      uid = 'post:realm$1'
      Item.create!(:external_uid => uid)
      post "/reports/#{uid}"
      post "/reports/#{uid}"
      post "/reports/#{uid}"
      report = Report.first
      report.reporter.should be_nil
      report.item.external_uid.should eq uid
      report.item.uid.should eq "snitchitem.#{uid}"
      report.item.report_count.should eq 3
    end

    it "won't let me report a decision 'cause I'm nobody" do
      post "/items/thing:testrealm$thong/actions", :action => {:kind => 'kept'}
      last_response.status.should eq 403
    end

  end

  describe "counts" do
    before(:each) do
      user!
    end

    it "it get counts" do
      Item.create!(:external_uid => "klass1:apdm.calendar$1")
      Item.create!(:external_uid => "klass2:apdm.calendar$2")
      Item.create!(:external_uid => "klass2:apdm.blogs$3")
      post "/reports/klass1:apdm.calendar$1"
      post "/reports/klass2:apdm.calendar$2"
      post "/reports/klass2:apdm.blogs$3"

      get "/items/*:apdm.*/count"
      JSON.parse(last_response.body)['uid'].should eq "*:apdm.*"
      JSON.parse(last_response.body)['count'].should eq 3
    end
  end
end
