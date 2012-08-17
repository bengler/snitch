class UsePebblePath < ActiveRecord::Migration
  def self.up
    labels = [:label_0, :label_1, :label_2, :label_3, :label_4, :label_5, :label_6, :label_7, :label_8, :label_9]
    labels.each do |label|
      add_column :items, label, :text
    end
    add_index :items, labels, :name => 'index_scores_on_labels'

    add_column :items, :klass, :text
    add_index :items, :klass
    
    add_column :items, :oid, :text
    add_index :items, :oid

    say "Migrating existing paths to pebble_path"

    counter = 0
    execute("SELECT id, uid FROM items").each do |item|
      counter += 1
      say " ... processed #{counter} items" if (counter % 100) == 0

      id = item["id"]
      klass, path, oid = Pebblebed::Uid.parse(item['uid'])

      labels = path.split('.')
      new_values = []
      labels.each_with_index do |label, i|
        new_values << "label_#{i}='#{label}'"
      end
      new_values << "klass = '#{klass}'"
      new_values << "oid = '#{oid}'"

      sql = "UPDATE items SET #{new_values.join(', ')} WHERE id=#{id}"
      execute(sql)
    end

    remove_column :items, :uid
  end

  def self.down
  end
end
