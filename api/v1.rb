# encoding: utf-8
require "json"
require 'pebblebed/sinatra'
require 'tilt/petroglyph'
require 'sinatra/petroglyph'

Dir.glob("#{File.dirname(__FILE__)}/v1/**/*.rb").each{ |file| require file }

class SnitchV1 < Sinatra::Base
  set :root, "#{File.dirname(__FILE__)}/v1"

  register Sinatra::Pebblebed

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
    # Only look for existing reports for logged in users
    reporter = current_identity && current_identity[:id]
    existing_report = if reporter
      item = Item.find_by_uid(uid)
      Report.find_by_item_id_and_reporter(item.id, reporter) if item
    end
    Report.create!(:uid => uid, :reporter => reporter) unless existing_report
    [200, "Ok"]
  end

  get '/items/?:uid?' do
    require_god # TODO: Rather check that the user is a moderator
    if params[:uid] =~ /\,/
      # Retrieve a list of items with null-placeholders for missing items to
      # guaranatee exact same output order as input order
      uids = params[:uid].split(/\s*,\s*/).compact
      items = []
      uids.each { |uid| items << (item = Item.find_by_uid(uid.strip); item ? item : {})}
      items, pagination = items, {:limit => items.count, :offset => 0, :last_page => true}
      return pg :items, :locals => {:items => items, :pagination => pagination}
    else
      klass = '*'
      oid = nil
      path = params[:path]
      klass, path, oid = Pebblebed::Uid.raw_parse(params[:uid]) if params[:uid]
      require_parameters(params, :path) unless path
      items = Item.by_path(path).order("created_at desc")
      items = items.where(:klass => klass) unless klass == '*'
      params[:scope] ||= 'pending'
      if params[:scope] == 'fresh'
        items = items.fresh
      elsif params[:scope] == 'reported'
        items = items.reported
      elsif params[:scope] == 'processed'
        items = items.processed
      elsif params[:scope] == 'pending'
        items = items.unprocessed.reported
      else
        halt 400, "Unknown scope #{params[:scope]}"
      end
    end
    items, pagination = limit_offset_collection(items, params)
    pg :items, :locals => {:items => items, :pagination => pagination}
  end

  post '/items/:uid' do |uid|
    require_god
    item = Item.find_or_create_by_uid(uid)
    pg :item, :locals => {:item => item}
  end

  post '/items/:uid/actions' do |uid|
    require_god
    halt 400, "Decision must be one of #{Action::KINDS.join(', ')}." unless Action::KINDS.include?(params[:action][:kind])    
    action = nil
    ActiveRecord::Base.connection.transaction do
      item = Item.find_or_create_by_uid(uid)
      action = Action.create!(params[:action].merge(:item => item, :identity => current_identity.id))
    end
    pg :action, :locals => {:action => action}
  end

  get '/items/:uid/actions' do |uid|
    require_god

    if params[:since]
      since = Time.parse(params[:since])
    else
      # One month ago
      since = Time.now-24*60*60*30
    end

    items = Item.by_wildcard_uid(uid).where("action_at > ?", since)
    actions = Action.where("item_id in (?)", items.map(&:id)).where("created_at > ?", since).order("created_at desc")
    actions, pagination = limit_offset_collection(actions, params)
    pg :actions, :locals => {:actions => actions, :pagination => pagination}
  end

  # REPLACED WITH POST /items/*/actions
  # Reinstate this method if you must. It has been ported to work with the new snitch, but we'd rather like to 
  # get rid of it, mmmkay?
  # post '/items/:uid/decision' do |uid|
  #   require_god # TODO: Rather check that the user is a moderator of the current realm
  #   decision = params[:item][:decision].downcase.strip
  #   halt 400, "Decision must be one of ${Item::DECISIONS.join(', ')}." unless Item::DECISIONS.include?(decision)
  #   item = Item.find_or_create_by_uid(uid)
  #   item.decision = decision
  #   Action.create!(:item => item, :actor => current_identity.id, :action => params[:item][:decision])
  #   item.decider = current_identity.id
  #   item.decision_at = Time.now
  #   item.save!
  #   pg :item, :locals => {:item => item}
  # end
end
