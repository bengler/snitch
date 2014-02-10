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

  before do
    # If this service, for some reason, lives behind a proxy that rewrites the Cache-Control headers into
    # "must-revalidate" (which IE9, and possibly other IEs, does not respect), these two headers should properly prevent
    # caching in IE (see http://support.microsoft.com/kb/234067)
    headers 'Pragma' => 'no-cache'
    headers 'Expires' => '-1'

    cache_control :private, :no_cache, :no_store, :must_revalidate
  end

  # @apidoc
  # Report a resource as objectionable.
  #
  # @description Uses checkpoint to attach a user to the report, but accepts anonymous reports.
  # @category Snitch
  # @path /api/snitch/v1/reports/:uid
  # @http POST
  # @example /api/snitch/v1/reports/post.entry:acme.discussions.cats-vs-dogs$2342343
  # @required [String] uid Pebbles uid denoting a resource
  # @optional [String] kind Application-specific tag to denote kind of objection
  # @optional [String] comment A comment from the reporting user
  # @status 200 OK
  post '/reports/:uid' do |uid|
    item = Item.find_by_external_uid(uid)
    halt 404, "No such item" unless item
    reporter = current_identity && current_identity[:id]
    kind = params[:kind]
    comment = params[:comment]
    existing_report = if reporter && kind.nil?
      Report.find_by_item_id_and_reporter_and_kind(item.id, reporter, nil) if item
    end
    if !existing_report
      Report.create!(:uid => uid, :reporter => reporter, :kind => kind, :comment => comment)
    end
    [200, "Ok"]
  end

  # @apidoc
  # Return a paginated list of unprocessed reported resources (i.e. for a moderator to review).
  #
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
      uids.each { |uid| items << (item = Item.find_by_external_uid(uid); item ? item : {})}
      pagination = {:limit => items.count, :offset => 0, :last_page => true}
      return pg :items, :locals => {:items => items, :pagination => pagination}
    else
      klasses = extract_klasses_from_query(query)
      params[:scope] ||= 'pending'
      items = Item.by_path(query.path).order("#{sort_by_from_params} #{order_from_params}")
      items = items.where(:klass => klasses) if klasses.any?
      items = items.where(:klass => query.species) if query.species? and !klasses.any?
      items = get_items_from_scope(params[:scope], items)
    end
    items, pagination = limit_offset_collection(items, params)
    pg :items, :locals => {:items => items, :pagination => pagination}
  end

  # @apidoc
  # Return count on how many items there arefor a wildcard uid
  #
  #
  # @category Snitch
  # @path /api/snitch/v1/items/:uid/count
  # @http GET
  #
  # @example /api/snitch/v1/items/post.entry:acme.discussions.*/count
  #
  # @optional [String] scope The scope of the reports to fetch. Must be any of
  #   "pending" (any reported items that have no registered decision),
  #   "processed" (Items that have been decided upon),
  #   "reported" (all reported items, including items that have recieved a decision),
  #   "fresh" (any fresh content that has not been marked as seen by a moderator).
  #   If not specified. Default scope is "pending".
  get '/items/:uid/count' do |uid|
    query = Pebbles::Uid.query(uid) if uid
    query ||= Pebbles::Uid.query("*:#{params[:path]}") if params[:path]
    query ||= Pebbles::Uid.query("*:#{current_identity.realm}.*")
    klasses = extract_klasses_from_query(query)
    params[:scope] ||= 'pending'
    items = Item.by_path(query.path).order("#{sort_by_from_params} #{order_from_params}")
    items = items.where(:klass => klasses) if klasses.any?
    items = items.where(:klass => query.species) if query.species? and !klasses.any?
    items = get_items_from_scope(params[:scope], items)
    content_type :json
    {:uid => uid, :count => items.count}.to_json
  end

  # @apidoc
  # Notify snitch of the existence of a resource
  # @description This is used to notify snitch of the existence of a new resource (i.e. for moderating resources as it
  #   is submitted) To let snitch know a moderator has seen an item, post an action of the kind "seen" (any other action
  #   will also mark the item as seen).
  # @note :uid is eventually stored as :external_uid on the Item
  # @category Snitch
  # @path /api/snitch/v1/items/:uid
  # @example /api/snitch/v1/items/post.entry:acme.discussions.cats-vs-dogs$99923
  # @http POST
  # @category Snitch
  post '/items/:uid' do |uid|
    require_god
    item = Item.find_or_create_by_external_uid(uid)
    pg :item, :locals => {:item => item}
  end

  # @apidoc
  # Register a moderator decision
  #
  # @note Requires moderator access
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
  # @required [String] uid A full or a wildcard uid for what to register desicion on.
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

    query = Pebbles::Uid.query(uid) if uid
    require_action_allowed(:create, uid) if query.oid

    halt 400, "No action given with request" unless params[:action]
    halt 400, "Decision must be one of #{Action::KINDS.join(', ')}." unless Action::KINDS.include?(params[:action][:kind])

    if query.oid
      action = nil
      ActiveRecord::Base.connection.transaction do
        item = Item.find_or_create_by_external_uid(uid)
        action = Action.create!(params[:action].merge(
          :item => item, :identity => current_identity.id))
      end
      pg :action, :locals => {:action => action}
    else
      action = params[:action]
      kind = action["kind"]
      klasses = extract_klasses_from_query(query)
      items = Item.by_path(query.path)
      items = items.where(:klass => klasses) if klasses.any?
      items = items.where(:klass => query.species) if query.species? and !klasses.any?
      if items.count > 0
        require_action_allowed(:create, items.first.external_uid)
        if kind == 'seen'
          items.update_all("seen = true")
        elsif Item::DECISIONS.include?(kind)
          items.update_all("seen = true, desicion = '#{kind}', decider = #{current_identity.id}")
        end
        item = items.first
        action = Action.create!(params[:action].merge(
            :item => item, :identity => current_identity.id))
        pg :action, :locals => {:action => action}
      else
        halt 404, "No items found for #{uid}"
      end
    end
  end


  # @apidoc
  # Get lists of moderator decisions
  #
  # @description Returns a paginated list of recent actions on items matching the wildcard uid sorted by date. By default
  # this will only go as far back as 30 days for performance reasons. By passing a date to the parameter :since you may
  # page even further back.
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
    items = Item.by_wildcard_external_uid(uid)
    items = items.where("action_at > ?", since)
    actions = Action.where("item_id in (?)", items.map(&:id)).where(
      "created_at > ?", since).order("created_at desc")
    actions, pagination = limit_offset_collection(actions, params)
    pg :actions, :locals => {:actions => actions, :pagination => pagination}
  end

  # @apidoc
  # Get a list of submitted reports for the given item
  #
  # @description Returns a paginated list of submitted reports for the given item
  # @path /api/snitch/v1/items/:uid/reports
  # @http GET
  # @category Snitch
  # @example /api/snitch/v1/items/post.entry:acme.discussions.cats-vs-dogs$42/reports
  # @required [String] uid Pebbles uid denoting a resource
  get '/items/:uid/reports' do |uid|
    require_action_allowed(:create, uid) # FIXME: Temporary until we have PSM3
    item = Item.find_by_external_uid(uid)
    reports = (item ? item.reports : Report.where('false'))
    reports, pagination = limit_offset_collection(reports, params)
    pg :reports, :locals => {:reports => reports, :pagination => pagination}
  end


  helpers do

    def get_items_from_scope(scope, items)
      case scope
        when 'not_removed'
          items.not_removed
        when 'seen_and_not_removed'
          items.seen_and_not_removed
        when 'kept'
          items.kept
        when 'removed'
          items.removed
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

    def extract_klasses_from_query(query)
      species_0 = nil
      klasses = []
      query_to_hash = query.to_hash
      if query_to_hash[:species_0].is_a?(Array)
        klasses = query_to_hash[:species_0]
      else
        query_to_hash.map do |key, value|
          if key.to_s.match("species")
            if key.to_s == "species_0"
              species_0 = value
            elsif species_0 and value.is_a?(Array)
              value.each do |v|
                klasses << "#{species_0}.#{v}"
              end
            end
          end
        end
      end
      klasses
    end

  end # helpers

end
