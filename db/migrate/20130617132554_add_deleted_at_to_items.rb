class AddDeletedAtToItems < ActiveRecord::Migration
  def self.up
    add_column :items, :deleted_at, :timestamp
  end

  def self.down
    remove_column :items, :deleted_at
  end
end
