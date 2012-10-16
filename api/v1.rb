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
    query = Pebbles::Uid.query(params[:uid]) if params[:uid]
    query ||= Pebbles::Uid.query("*:#{params[:path]}") if params[:path]
    query ||= Pebbles::Uid.query("*:#{current_identity.realm}.*")
    if query.list?
      # Retrieve a list of items with null-placeholders for missing items to
      # guaranatee exact same output order as input order
      uids = query.list
      items = []
      uids.each { |uid| items << (item = Item.find_by_uid(uid); item ? item : {})}
      pagination = {:limit => items.count, :offset => 0, :last_page => true}
      return pg :items, :locals => {:items => items, :pagination => pagination}
    else
      params[:scope] ||= 'pending'
      items = Item.by_path(query.path).order(
        "#{sort_by_from_params} #{order_from_params}")
      items = items.where(:klass => query.species) if query.species?
      items = case params[:scope]
        when 'fresh'
          items.fresh
        when 'reported'
          items.reported
        when 'processed'
          items.processed
        when 'pending'
          items.unprocessed.reported
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
    unless Action::KINDS.include?(params[:action][:kind])
      halt 400, "Decision must be one of #{Action::KINDS.join(', ')}."
    end
    action = nil
    ActiveRecord::Base.connection.transaction do
      item = Item.find_or_create_by_uid(uid)
      action = Action.create!(params[:action].merge(
        :item => item, :identity => current_identity.id))
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
    actions = Action.where("item_id in (?)", items.map(&:id)).where(
      "created_at > ?", since).order("created_at desc")
    actions, pagination = limit_offset_collection(actions, params)
    pg :actions, :locals => {:actions => actions, :pagination => pagination}
  end

  helpers do

    def order_from_params
      case params[:order]
        when "asc", "ASC"
          "asc"
        when "desc", "DESC"
          "desc"
        else
          "desc"
      end
    end

    def sort_by_from_params
      case params[:sort_by]
        when "created_by"
          "created_by"
        when "action_at"
          "action_at"
        when "updated_at"
          "updated_at"
        else
          "created_at"
      end
    end

    def limit_offset_collection(collection, options)
      limit = (options[:limit] || 20).to_i
      offset = (options[:offset] || 0).to_i
      collection = collection.limit(limit+1).offset(offset)
      last_page = (collection.size <= limit)
      metadata = {
        :limit => limit,
        :offset => offset,
        :last_page => last_page
      }
      collection = collection[0..limit-1]
      [collection, metadata]
    end

  end # helpers

end
