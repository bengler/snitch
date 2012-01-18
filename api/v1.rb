# encoding: utf-8
require "json"
require 'pebblebed/sinatra'
require 'tilt/petroglyph'
require 'sinatra/petroglyph'

Dir.glob("#{File.dirname(__FILE__)}/v1/**/*.rb").each{ |file| require file }

class SnitchV1 < Sinatra::Base
  set :root, "#{File.dirname(__FILE__)}/v1"

  register Sinatra::Pebblebed
  i_am :snitch

  declare_pebbles do
    service 'checkpoint'
  end

  helpers do
    def limit_offset_collection(collection, options)
      limit = (options[:limit] || 20).to_i
      offset = (options[:offset] || 0).to_i
      collection = collection.limit(limit+1).offset(offset)
      last_page = (collection.size <= limit)
      metadata = {:limit => limit, :offset => offset, :last_page => last_page}
      collection = collection[0..limit-1]
      [collection, metadata]
    end
  end  

  post '/reports/:uid' do |uid|
    existing_report = begin
      # Only look for existing reports for logged in users
      if current_identity[:id]
        item = Item.find_by_uid(uid)    
        Report.find_by_item_id_and_reporter(item.id, current_identity.id) if item
      end
    end
    Report.create!(:uid => uid, :reporter => current_identity[:id]) unless existing_report
    [200, "Ok"]
  end

  get '/items' do
    require_god # TODO: Rather check that the user is a moderator
    require_parameters(params, :path)
    labels = params[:path].split('.')
    halt 500, "At present paths may only be one deep (realm)" if labels.size > 1
    realm = labels.first
    items = Item.where("realm = ?", realm).order("created_at desc")
    items = items.unprocessed unless params[:include_processed] && params[:include_processed] != 'false'
    items, pagination = limit_offset_collection(items, params)
    pg :items, :locals => {:items => items, :pagination => pagination}
  end

  post '/items/:uid/decision' do |uid|
    require_god # TODO: Rather check that the user is a moderator of the current realm
    decision = params[:item][:decision].downcase.strip
    halt 400, "Decision must be one of ${Item::DECISIONS.join(', ')}." unless Item::DECISIONS.include?(decision)
    item = Item.find_or_create_by_uid(uid)
    item.decision = decision
    item.decider = current_identity.id
    item.decision_at = Time.now
    item.save!
    pg :item, :locals => {:item => item}
  end

  get '/ping' do
    failures = []

    begin
      ActiveRecord::Base.verify_active_connections!
      ActiveRecord::Base.connection.execute("select 1")
    rescue Exception => e
      failures << "ActiveRecord: #{e.message}"
    end

    if failures.empty?
      halt 200, "snitch"
    else
      halt 503, failures.join("\n")
    end
  end
end
