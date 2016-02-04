require 'pebblebed'
require 'petroglyph'

require_relative 'models/report'

class RiverNotifications < ActiveRecord::Observer

  observe Report

  def self.river
    @river ||= Pebblebed::River.new
  end

  def after_create(report)
    publish(report, :create) if should_publish?(report)
  end

  def publish(report, event)
    self.class.river.publish(
      :event => event,
      :uid => report.uid,
      :attributes => report.to_petroglyph[:report]
    )
  end


  private

    def should_publish?(object)
      return true if object.is_a?(Report)
      false
    end

end
