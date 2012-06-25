class Item < ActiveRecord::Base
  include PebblePath

  has_many :reports
  has_many :actions, :order => "created_at desc"

  before_save :parse_uid

  # Lists the valid decisions (must be a subset of Action::KINDS)
  DECISIONS = ['removed', 'kept']

  validates_inclusion_of :decision, :in => DECISIONS, :allow_nil => true

  scope :unprocessed, where("decision is null")

  scope :by_wildcard_uid, lambda { |uid| 
    klass, path, oid = Pebblebed::Uid.raw_parse(uid)
    scope = by_path(path)
    scope = where(:klass => klass) unless klass == '*'
    scope = where(:oid => oid) if oid && oid != '*'
    scope
  }

  def self.find_by_uid(uid)
    self.by_wildcard_uid(uid).first
  end

  def self.find_or_create_by_uid(uid)
    item = self.find_by_uid(uid)
    unless item
      item = Item.new(:uid => uid) 
      item.save!
    end
    item
  end

  def realm 
    label_0
  end

  def uid
    "#{klass}:#{path}$#{oid}"
  end

  def uid=(uid)
    self.klass, self.path, self.oid = Pebblebed::Uid.parse(uid)
  end

  private

  def parse_uid
    self.uid = attributes[:uid] if attributes[:uid]
    attributes[:uid] = nil
  end
end