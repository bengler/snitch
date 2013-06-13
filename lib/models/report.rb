class Report < ActiveRecord::Base

  belongs_to :item, :counter_cache => :report_count
  before_create :ensure_item

  def uid=(value)
    if !new_record? && self.uid != value
      raise "Can't update uid for existing record"
    end
    @uid = value
  end

  def uid
    self.item.external_uid
  end

  private

  def ensure_item
    self.item = Item.find_or_create_by_external_uid(@uid)
  end
end
