require 'pebblebed'
require 'petroglyph'

require_relative 'models/report'

class RiverNotifications < ActiveRecord::Observer
  observe :report

  def self.river
    @river ||= Pebblebed::River.new
  end

  def after_create(report)
    publish(report, :create)
  end

  def publish(report, event)
    self.class.river.publish(
      :event => event,
      :uid => report.uid,
      :attributes => report.to_petroglyph[:report]
    )
  end

end
