class Report < ActiveRecord::Base
  include Petroglyphy

  belongs_to :item, :counter_cache => :report_count
  before_create :ensure_item, :unset_decision

  def uid=(value)
    if !new_record? && self.uid != value
      raise "Can't update uid for existing record"
    end
    @uid = value
  end

  def uid
    "snitchreport.#{external_uid}"
  end

  def external_uid
    self.item.external_uid
  end

  private

  def unset_decision
    item = self.item
    item.decision = nil
    item.decider = nil
    item.save
  end

  # TODO: get rid of this. A report cannot exist witout an item.
  def ensure_item
    self.item = Item.find_or_create_by_external_uid(@uid)
  end
end
