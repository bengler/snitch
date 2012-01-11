class Item < ActiveRecord::Base
  has_many :reports

  before_save :extract_realm

  DECISIONS = ['removed', 'kept']

  scope :unprocessed, where("decision is null")

  private

  def extract_realm
    klass, path, oid = Pebblebed::Uid.parse(self.uid)
    self.realm = path.split('.').first
  end
end