class Item < ActiveRecord::Base
  include PebblePath

  has_many :reports

  before_save :parse_uid

  DECISIONS = ['removed', 'kept']

  scope :unprocessed, where("decision is null")

  def self.find_by_uid(uid)
    klass, path, oid = Pebblebed::Uid.parse(uid)
    self.where(:klass => klass, :oid => oid).by_path(path).first
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