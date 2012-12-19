class Action < ActiveRecord::Base
  belongs_to :item, :touch => :action_at

  KINDS = ['removed', 'kept', 'edited', 'seen', 'recommended', 'recommendation_revoked']

  validates_inclusion_of :kind, :in => KINDS

  after_save :apply_decision

  def uid
    @uid ||= item.uid
  end

  private

  # Apply action to item if the kind is a valid decision
  def apply_decision
    if kind == 'seen'
      item.seen = true
      item.save!
    end

    if Item::DECISIONS.include?(self.kind)
      item.seen = true
      item.decision = self.kind
      item.decider = self.identity
      item.save!
    end
  end

end
