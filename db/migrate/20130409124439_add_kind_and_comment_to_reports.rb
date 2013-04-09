class AddKindAndCommentToReports < ActiveRecord::Migration
  def self.up
    add_column :reports, :kind, :string
    add_column :reports, :comment, :text

    remove_index :reports, :column => [:item_id, :reporter], :unique => true

    add_index :reports, :item_id
  end

  def self.down
  end
end
