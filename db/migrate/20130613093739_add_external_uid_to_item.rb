class AddExternalUidToItem < ActiveRecord::Migration
  def self.up
    add_column :items, :external_uid, :text, :null => false
    Item.all.each do |item|
      item.external_uid = Pebbles::Uid.build(item.klass, item.path, item.oid)
      item.save
    end
  end

  def self.down
    Item.all.each do |item|
      external_species, _, _ = Pebbles::Uid.parse(item.external_uid)
      item.klass = external_species
      item.save
    end
    remove_column :items, :external_uid
  end
end
