class Item < ActiveRecord::Base
  include Pebbles::Path
  include Petroglyphy

  has_many :reports
  has_many :actions, :order => "created_at desc"

  # Lists the valid decisions (must be a subset of Action::KINDS)
  DECISIONS = ['removed', 'kept']

  validates_inclusion_of :decision, :in => DECISIONS, :allow_nil => true

  scope :unprocessed, where("decision is null")
  scope :processed, where("decision is not null")
  scope :fresh, where("not seen")
  scope :reported, where("report_count > 0")
  scope :kept, where("decision = 'kept'")
  scope :removed, where("decision = 'removed'")
  scope :seen_and_not_removed, where("seen is true and (decision != 'removed' or decision is null)")
  scope :not_removed, where("decision != 'removed' or decision is null")

  scope :by_wildcard_external_uid, lambda { |uid|
    query = Pebbles::Uid.query(uid)
    scope = by_path(query.path)
    scope = where(:klass => query.species) if query.species?
    scope = where(:oid => query.oid) if query.oid?
    scope
  }

  def self.find_by_external_uid(uid)
    self.by_wildcard_external_uid(uid).first
  end

  def self.find_or_create_by_external_uid(uid)
    item = self.find_by_external_uid(uid)
    unless item
      item = Item.new
      item.external_uid = uid
      item.save!
    end
    item
  end

  def realm
    label_0
  end

  def uid
    "snitchitem.#{external_uid}"
  end

  def external_uid
    Pebbles::Uid.build(self.klass, self.path, self.oid)
  end

  def external_uid=(value)
    self.klass, self.path, self.oid = Pebbles::Uid.parse(value)
  end


  def deleted?
    destroyed? || decision == 'removed'
  end

end
