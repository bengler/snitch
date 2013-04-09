class AddKindAndCommentToReports < ActiveRecord::Migration
  def self.up
    add_column :reports, :kind, :string
    add_column :reports, :comment, :text
  end

  def self.down
    remove_column :reports, :kind
    remove_column :reports, :comment
  end
end
