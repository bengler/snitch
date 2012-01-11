class Item < ActiveRecord::Base
  has_many :reports

  before_save :extract_realm

  DECISIONS = ['removed', 'kept']

  private

  def extract_realm
    klass, path, oid = Pebblebed::Uid.parse(self.uid)
    realm = path.split('.').first
  end
end