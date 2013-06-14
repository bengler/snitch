require 'pebblebed'
require 'petroglyph'

require_relative 'models/item'

class RiverNotifications < ActiveRecord::Observer
  observe :item

  def self.river
    @river ||= Pebblebed::River.new
  end

  def after_create(item)
    publish(item, :create)
  end

  def after_update(item)
    if item.deleted?
      publish(item, :delete)
    else
      publish(item, :update)
    end
  end

  def after_destroy(item)
    publish(item, :delete)
  end

  def publish(item, event)
    self.class.river.publish(
      :event => event,
      :uid => item.uid,
      :attributes => item.to_petroglyph[:item]
    )
  end

end
