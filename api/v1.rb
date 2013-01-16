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

  # @apidoc
  # Report a resource as objectionable.
  #
  # @description Uses checkpoint to attach a user to the report, but accepts anonymous reports.
  # @category Snitch
  # @path /api/snitch/v1/reports/:uid
  # @http POST
  # @example /api/snitch/v1/reports/post.entry:acme.discussions.cats-vs-dogs$2342343
  # @required [String] Pebbles uid denoting a resource
  # @status 200 OK
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

  # @apidoc
  # Return a paginated list of unprocessed reported resources (i.e. for a moderator to review).
  #
  # @note Currently requires god permission
  #
  # @category Snitch
  # @path /api/snitch/v1/items/:uid
  # @http GET
  #
  # @example /api/snitch/v1/items/post.entry:acme.discussions.cats-vs-dogs$*
  # @example /api/snitch/v1/items/post.entry:acme.discussions.cats-vs-dogs$1,post.entry:acme.discussions.cats-vs-dogs$2
  #
  # @optional [String] scope The scope of the reports to fetch. Must be any of
  #   "pending" (any reported items that have no registered decision),
  #   "processed" (Items that have been decided upon),
  #   "reported" (all reported items, including items that have recieved a decision),
  #   "fresh" (any fresh content that has not been marked as seen by a moderator).
  #   If not specified. Default scope is "pending".
  # @optional [String] sort_by Any of "created_at", "updated_at" or "action_at" Defaults to "created_at".
  # @optional [String] order Either "asc" or "desc". Defaults to "desc".
  # @optional [Integer] offset Index of the first returned hit. Defaults to 0.
  # @optional [Number] limit Maximum number of returned hits. Defaults to 10.
  # @description You may also input a list of full UIDs, e.g GET /items/a.b.c$1,a.b.c$2,a.b.c$3. For this type of query
  #   pagination will not be possible as it always returns the exact items and in the exact order as the input uid list.
  #   If an item is not found, it will output a null item in the same position as the input.
  get '/items/?:uid?' do
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

  # @apidoc
  # Notify snitch of the existence of a resource
  # @description This is used to notify snitch of the existence of a new resource (i.e. for moderating resources as it
  #   is submitted) To let snitch know a moderator has seen an item, post an action of the kind "seen" (any other action
  #   will also mark the item as seen).
  # @category Snitch
  # @path /api/snitch/v1/items/:uid
  # @example /api/snitch/v1/items/post.entry:acme.discussions.cats-vs-dogs$99923
  # @http POST
  # @category Snitch
  post '/items/:uid' do |uid|
    require_god
    item = Item.find_or_create_by_uid(uid)
    pg :item, :locals => {:item => item}
  end

  # @apidoc
  # Register a moderator decision
  #
  # @note Requires god
  # @description Actual removal of content is not performed by snitch, but this will remove the item from the
  #   default list returned by GET /items.
  #   Currently the user reporting a decision must be god of the given realm, but this should be considered a
  #   temporary solution until a proper concept of "moderators" is in place. Both the decision and the decider is
  #   registered with the item in question.
  #
  # @category Snitch
  # @http POST
  #
  # @path /api/snitch/v1/items/:uid/actions
  #
  # @required [JSON] action
  # @required [String] action[kind] One of "kept", "removed", "seen", "edited", "recommended" or "recommendation_revoked".
  # @optional [String] action[rationale] Optionally you can provide a "rationale" label to explain the reason for the
  #   action. Example rationales could be "irrelevant", "adhominem", "hatespeech", "legal", etc.
  # @optional [String] action[message] An additional human readable explanation of the action. This should be directed
  #   at the offender as this message in the future may be provided to the original poster.
  #
  # @example /api/snitch/v1/items/post.entry:acme.discussions.cats-vs-dogs$99923/actions?action[kind]=kept
  #
  post '/items/:uid/actions' do |uid|
    require_god

    halt 400, "No action given with request" unless params[:action]
    halt 400, "Decision must be one of #{Action::KINDS.join(', ')}." unless Action::KINDS.include?(params[:action][:kind])

    action = nil
    ActiveRecord::Base.connection.transaction do
      item = Item.find_or_create_by_uid(uid)
      action = Action.create!(params[:action].merge(
        :item => item, :identity => current_identity.id))
    end
    pg :action, :locals => {:action => action}
  end

  # @apidoc
  # Get lists of moderator decisions
  #
  # @description Returns a paginated list of recent actions on items matching the wildcard uid sorted by date. By default
  # this will only go as far back as 30 days for performance reasons. By passing a date to the parameter :since you may
  # page even further back.
  # @note Requires god
  # @path /api/snitch/v1/items/:uid/actions
  # @http GET
  # @category Snitch
  # @example /api/snitch/v1/items/post.entry:acme.discussions.cats-vs-dogs$*/actions
  get '/items/:uid/actions' do |uid|
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
