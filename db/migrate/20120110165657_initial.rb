class Initial < ActiveRecord::Migration
  def self.up
    create_table "reports" do |t|
      t.integer 'item_id'
      t.integer 'reporter'
      t.timestamps
    end
    add_index :reports, [:item_id, :reporter], :unique => true

    create_table "items" do |t|
      t.text 'uid', :unique => true
      t.text 'realm'
      t.integer 'report_count', :default => 0
      t.text 'decision'
      t.integer 'decider'
      t.timestamp 'decision_at'
      t.timestamps
    end
    add_index :items, :uid, :unique => true
    add_index :items, :realm
    add_index :items, :created_at
  end

  def self.down
  end
end
