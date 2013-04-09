class Report < ActiveRecord::Base
  belongs_to :item, :counter_cache => :report_count

  validates :reporter, :uniqueness => {:scope => [:item_id, :kind]}

  before_create :ensure_item

  def uid=(value)
    if !new_record? && self.uid != value
      raise "Can't update uid for existing record"
    end
    @uid = value
  end

  def uid
    @uid ||= self.item.uid
  end

  private

  def ensure_item
    self.item = Item.find_or_create_by_uid(@uid)
  end
end
