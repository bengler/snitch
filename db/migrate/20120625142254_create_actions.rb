class CreateActions < ActiveRecord::Migration
  def self.up
    create_table "actions" do |t|
      t.integer "item_id"
      t.integer "identity"
      t.text "kind"
      t.text "rationale"
      t.text "message"
      t.timestamps
    end
    add_index :actions, :item_id
    add_index :actions, :identity

    say "Creating actions from decisions"
    execute("select * from items where decision is not null").each do |item|
      execute "insert into actions (item_id, identity, kind, rationale, created_at) values 
        (#{item['id']}, #{item['decider']}, '#{item['decision']}', 'unspecified', '#{item['decision_at']}')"
    end

    rename_column :items, :decision_at, :action_at
  end

  def self.down
  end
end
