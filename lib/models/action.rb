class Action < ActiveRecord::Base
  belongs_to :item, :touch => :action_at
  
  KINDS = ['removed', 'kept', 'edited', 'seen']

  RATIONALES = ['practical', 'relevance', 'adhominem', 'hatespeech', 'doublepost', 'legal', 'advertising', 'policy']

  validates_inclusion_of :kind, :in => KINDS
  validates_inclusion_of :rationale, :in => RATIONALES, :allow_nil => true

  after_save :apply_decision

  def uid
    @uid ||= item.uid
  end

  private

  # Apply action to item if the kind is a valid decision
  def apply_decision
    if Item::DECISIONS.include?(self.kind)
      item.seen = true
      item.decision = self.kind
      item.decider = self.identity
      item.save!
    end
  end

end
