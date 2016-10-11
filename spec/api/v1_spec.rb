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
      expect(item.uid).to eq "snitchitem.#{uid}"
      expect(item.external_uid).to eq uid
      expect(item.report_count).to eq 0
      expect(item.decision).to eq 'kept'
      expect(item.action_at).to_not be_nil
      expect(item.decider).to eq 1
    end

    it "lets me report a decision on a wildcard path" do
      uid = "thing:testrealm.calendar.*"
      Item.create!(:external_uid => "thing:testrealm.calendar.facebook$123")
      Item.create!(:external_uid => "thing:testrealm.calendar.origo$321")
      Item.create!(:external_uid => "thing:testrealm.foo.bar$123")
      checkpoint.should_receive(:post).at_least(1).times.with("/callbacks/allowed/create/thing:testrealm.calendar.facebook$123").and_return(access)
      post "/items/#{uid}/actions", :action => {:kind => 'seen'}
      expect(last_response.status).to eq 200
      expect(Item.find_by_external_uid("thing:testrealm.calendar.facebook$123").seen).to eq true
      expect(Item.find_by_external_uid("thing:testrealm.calendar.origo$321").seen).to eq true
      expect(Item.find_by_external_uid("thing:testrealm.foo.bar$123").seen).to eq false
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
      expect(oids).to eq ["9", "8", "7", "6", "5", "4", "3", "2", "1", "0"]

      # Register a decision and see the item is removed from the list
      post "/items/thing:testrealm$5/actions", :action => {:kind => 'removed'}
      get "/items", :path => "testrealm"
      result = JSON.parse(last_response.body)
      oids = result['items'].map do |record|
        record['item']['uid'][/\$\d*$/][1..-1]
      end
      expect(oids).to eq ["9", "8", "7", "6", "4", "3", "2", "1", "0"] # < with '5' removed
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
      expect(dates.sort{|a,b| b <=> a }).to eq dates

      get "/items", :path => "testrealm", :sort_by => "created_at", :order => "asc"
      result = JSON.parse(last_response.body)
      dates = result['items'].map do |record|
        record['item']['created_at']
      end
      expect(dates.sort{|a,b| a <=> b }).to eq dates
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
      expect(dates.sort{|a,b| b <=> a }).to eq dates

      get "/items", :path => "testrealm", :sort_by => "updated_at", :order => "asc"
      result = JSON.parse(last_response.body)
      dates = result['items'].map do |record|
        record['item']['updated_at']
      end
      expect(dates.sort{|a,b| a <=> b }).to eq dates
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
      expect(dates.sort{|a,b| b <=> a }).to eq dates

      get "/items", :path => "testrealm", :sort_by => "action_at", :order => "asc"
      result = JSON.parse(last_response.body)
      dates = result['items'].map do |record|
        record['item']['action_at']
      end
      expect(dates.sort{|a,b| a <=> b }).to eq dates
    end

    it "supports querying items by uid" do

      Item.create!(:external_uid => "klass1:apdm.calendar$1")
      post "/reports/klass1:apdm.calendar$1"
      Item.create!(:external_uid => "klass2:apdm.calendar$2")
      post "/reports/klass2:apdm.calendar$2"
      Item.create!(:external_uid => "klass2:apdm.blogs$3")
      post "/reports/klass2:apdm.blogs$3"

      get "/items/*:apdm.*"
      expect(JSON.parse(last_response.body)['items'].size).to eq 3

      get "/items/*:mittap.*"
      expect(JSON.parse(last_response.body)['items'].size).to eq 0

      get "/items/klass2:*"
      expect(JSON.parse(last_response.body)['items'].size).to eq 2

      get "/items/klass2:apdm.blogs"
      expect(JSON.parse(last_response.body)['items'].size).to eq 1
    end

    it "supports querying items by uids (multiple) with a null placeholder for missing items" do
      Item.create!(:external_uid => "klass1:apdm.calendar$1")
      post "/reports/klass1:apdm.calendar$1"
      Item.create!(:external_uid => "klass2:apdm.calendar$2")
      post "/reports/klass2:apdm.calendar$2"
      Item.create!(:external_uid => "klass2:apdm.blogs$3")
      post "/reports/klass2:apdm.blogs$3"

      get "/items/klass1:apdm.calendar$1,klass2:apdm.calendar$2,klass2:apdm.blogs$3,klass2:apdm.blogs$4"
      expect(JSON.parse(last_response.body)['items'].size).to eq 4
      expect(JSON.parse(last_response.body)['items'].last['item']).to be_nil
      expect(JSON.parse(last_response.body)['items'].select {|i| i['item'] == nil}.size).to eq 1
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
      expect(JSON.parse(last_response.body)['items'].size).to eq 2

      get "/items/post.foo%7Cbar%7Cbogus:apdm.*"
      expect(JSON.parse(last_response.body)['items'].size).to eq 3

      get "/items/bim%7Cbam:apdm.*"
      expect(JSON.parse(last_response.body)['items'].size).to eq 2

    end

    it "only accepts valid actions" do
      checkpoint.should_receive(:post).with("/callbacks/allowed/create/item:testrealm$somesort").and_return(access)
      checkpoint.should_receive(:post).with("/callbacks/allowed/create/item:testrealm$othersort").and_return(access)
      checkpoint.should_receive(:post).with("/callbacks/allowed/create/item:testrealm$thirdkind").and_return(access)
      post "/items/item:testrealm$somesort/actions", :action => {:kind => 'kept'}
      expect(last_response.status).to eq 200
      post "/items/item:testrealm$othersort/actions", :action => {:kind => 'removed'}
      expect(last_response.status).to eq 200
      post "/items/item:testrealm$thirdkind/actions", :action => {:kind => 'beloved'}
      expect(last_response.status).to eq 400
      expect(Action.count).to eq 2
    end

    it "denies access accross realms" do
      checkpoint.should_not_receive(:post).at_least(1).times.with("/callbacks/allowed/create/item:foo$somesort").and_return(access_denied)
      post "/items/item:foo$somesort/actions", :action => {:kind => 'kept'}
      expect(last_response.status).to eq 403
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
      expect(JSON.parse(last_response.body)['actions'].size).to eq 4

      get "/items/item:*/actions"
      expect(JSON.parse(last_response.body)['actions'].size).to eq 3

      get "/items/*:testrealm/actions"
      expect(JSON.parse(last_response.body)['actions'].size).to eq 3

      get "/items/item:testrealm.*/actions"
      expect(JSON.parse(last_response.body)['actions'].size).to eq 3
      get "/items/item:testrealm.*$one/actions"
      expect(JSON.parse(last_response.body)['actions'].size).to eq 2
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
      expect(last_response.status).to eq 200
      hash = JSON.parse(last_response.body)
      expect(hash).to have_key 'pagination'
      expect(hash).to have_key 'reports'
      expect(hash['reports'].size).to eq 4
      hash['reports'].each do |report_hash|
        report = report_hash['report']
        expect(report['uid']).to eq "snitchreport.#{uid}"
        expect(report['external_uid']).to eq uid
        expect(report['reporter']).to_not be_nil
        expect(report['created_at']).to_not be_nil
        expect(report).to have_key 'kind'
        expect(report).to have_key 'comment'
      end
    end

    it "provides an empty list of reports for an item Snitch doesn't know about" do
      uid = "item:testrealm$fourtytwo"
      checkpoint.should_receive(:post).at_least(1).times.
        with("/callbacks/allowed/create/#{uid}").and_return(access)
      get "/items/#{uid}/reports"
      expect(last_response.status).to eq 200
      hash = JSON.parse(last_response.body)
      expect(hash).to have_key 'reports'
      expect(hash['reports'].size).to eq 0
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
      expect(report.item.external_uid).to eq uid
      expect(report.reporter).to eq 1
      expect(report.kind).to be_nil
      expect(report.comment).to be_nil
      item = Item.first
      expect(item.realm).to eq "realm"
      expect(item.external_uid).to eq uid
      expect(item.report_count).to eq 1
    end

    it "accepts a report of objectionable content with kind and comment" do
      uid = 'post:realm$1'
      Item.create!(:external_uid => uid)
      post "/reports/#{uid}", :kind => 'bollox', :comment => 'Hogwash!'
      report = Report.first
      expect(report.uid).to eq "snitchreport.#{uid}"
      expect(report.reporter).to eq 1
      expect(report.kind).to eq 'bollox'
      expect(report.comment).to eq 'Hogwash!'
      item = Item.first
      expect(item.realm).to eq "realm"
      expect(item.uid).to eq "snitchitem.#{uid}"
      expect(item.external_uid).to eq uid
      expect(item.report_count).to eq 1
    end

    it "quietly rejects multiple reports from same user of same content with no kind" do
      uid = 'post:realm$1'
      Item.create!(:external_uid => uid)
      post "/reports/#{uid}"
      post "/reports/#{uid}"
      expect(last_response.status).to eq 200
      expect(Item.count).to eq 1
      item = Item.first
      expect(item.report_count).to eq 1
    end

    it "accepts multiple reports of same kind from same user of same content" do
      uid = 'post:realm$1'
      Item.create!(:external_uid => uid)
      post "/reports/#{uid}", :kind => 'foo'
      post "/reports/#{uid}", :kind => 'foo'
      expect(last_response.status).to eq 200
      expect(Item.count).to eq 1
      item = Item.first
      expect(item.report_count).to eq 2
    end

    it "accepts multiple reports of distinct kinds from same user of same content" do
      uid = 'post:realm$1'
      Item.create!(:external_uid => uid)
      post "/reports/#{uid}", :kind => 'foo'
      post "/reports/#{uid}", :kind => 'bar'
      expect(last_response.status).to eq 200
      expect(Item.count).to eq 1
      item = Item.first
      expect(item.report_count).to eq 2
    end

    it "disallows posting reports to a item that doesn't exist" do
      uid = 'post:realm$1'
      post "/reports/#{uid}", :kind => 'foo'
      expect(last_response.status).to eq 404
    end

    it "resets the decision on an item if it gets reported" do
      uid = 'post:realm$1'
      Item.create!(:external_uid => uid, :decision => "kept", :decider => 1)
      expect(Item.count).to eq 1
      expect(Item.first.decision).to eq 'kept'
      post "/reports/#{uid}", :kind => 'foo'
      expect(last_response.status).to eq 200
      expect(Item.count).to eq 1
      item = Item.first
      expect(item.decision).to be_nil
      expect(item.decider).to be_nil
    end

    it "counts distinct reports distinctly" do
      Report.create!(:uid => "dings:blah$1", :reporter => 4)
      Report.create!(:uid => "dings:blah$1", :reporter => 2)
      Report.create!(:uid => "dings:blah$1", :reporter => 3)
      Report.create!(:uid => "dings:blah$2", :reporter => 4)
      post "/reports/dings:blah$1"
      expect(Item.find_by_external_uid("dings:blah$1").report_count).to eq 4
      expect(Item.find_by_external_uid("dings:blah$2").report_count).to eq 1
    end

    it "won't let me report a decision 'cause I'm no admin" do
      uid = "thing:testrealm$thong2"
      Item.create!(:external_uid => uid)
      checkpoint.should_receive(:post).at_least(1).times.with("/callbacks/allowed/create/#{uid}").and_return(access_denied)
      checkpoint.should_receive(:get).at_least(1).times.with("/identities/me").and_return(group_user)
      Pebblebed::Connector.any_instance.stub(:checkpoint => checkpoint)
      post "/items/#{uid}/actions", :action => {:kind => 'kept'}
      expect(last_response.status).to eq 403
    end

    it "sets the realm correctly" do
      uid = 'post:realm$1'
      Item.create!(:external_uid => uid)
      post "/reports/#{uid}", :kind => 'foo'
      expect(Item.count).to eq 1
      item = Item.first
      expect(item.realm).to eq 'realm'
      expect(item.read_attribute(:realm)).to eq 'realm'
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
      expect(report.reporter).to be_nil
      expect(report.item.external_uid).to eq uid
      expect(report.item.uid).to eq "snitchitem.#{uid}"
      expect(report.item.report_count).to eq 3
    end

    it "won't let me report a decision 'cause I'm nobody" do
      post "/items/thing:testrealm$thong/actions", :action => {:kind => 'kept'}
      expect(last_response.status).to eq 403
    end

  end

  describe "with god user" do

    before(:each) do
      god!
    end

    it "allows item to be unseen" do
      post "/items/thing:testrealm$1"

      get "/items/thing:testrealm.*", scope: 'fresh'
      result = JSON.parse(last_response.body)
      expect(result['items'][0]['item']['uid']).to eq 'snitchitem.thing:testrealm$1'

      post "/items/thing:testrealm$1/actions", :action => {:kind => 'seen'}
      get "/items/thing:testrealm.*", scope: 'fresh'
      result = JSON.parse(last_response.body)
      expect(result["items"]).to eq []

      post "/items/thing:testrealm$1/unsee"
      get "/items/thing:testrealm.*", scope: 'fresh'
      result = JSON.parse(last_response.body)
      expect(result['items'][0]['item']['uid']).to eq 'snitchitem.thing:testrealm$1'
    end

    it "allows to specify identity for action which is another than current_identity" do
      post "/items/thing:testrealm$1/actions", :action => {:kind => 'seen', :identity => 333}

      get "/items/thing:testrealm$1/actions"
      result = JSON.parse(last_response.body)
      expect(result['actions'][0]['action']['identity']).to eq 333
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
      expect(JSON.parse(last_response.body)['uid']).to eq "*:apdm.*"
      expect(JSON.parse(last_response.body)['count']).to eq 3
    end
  end
end
