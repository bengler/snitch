class Report < ActiveRecord::Base
  belongs_to :item  

  before_create :ensure_item
  after_create :update_report_count

  scope :unprocessed, where("removed_by_moderator is null")

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

  def update_report_count
    Item.update_all("report_count = report_count + 1", "id = #{self.item.id}")
  end
end