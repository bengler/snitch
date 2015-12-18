# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20130409124439) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "actions", force: :cascade do |t|
    t.integer  "item_id"
    t.integer  "identity"
    t.text     "kind"
    t.text     "rationale"
    t.text     "message"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "actions", ["identity"], name: "index_actions_on_identity", using: :btree
  add_index "actions", ["item_id"], name: "index_actions_on_item_id", using: :btree

  create_table "items", force: :cascade do |t|
    t.text     "realm"
    t.integer  "report_count", default: 0
    t.text     "decision"
    t.integer  "decider"
    t.datetime "action_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "label_0"
    t.text     "label_1"
    t.text     "label_2"
    t.text     "label_3"
    t.text     "label_4"
    t.text     "label_5"
    t.text     "label_6"
    t.text     "label_7"
    t.text     "label_8"
    t.text     "label_9"
    t.text     "klass"
    t.text     "oid"
    t.boolean  "seen",         default: false
  end

  add_index "items", ["created_at"], name: "index_items_on_created_at", using: :btree
  add_index "items", ["klass"], name: "index_items_on_klass", using: :btree
  add_index "items", ["label_0", "label_1", "label_2", "label_3", "label_4", "label_5", "label_6", "label_7", "label_8", "label_9"], name: "index_scores_on_labels", using: :btree
  add_index "items", ["oid"], name: "index_items_on_oid", using: :btree
  add_index "items", ["realm"], name: "index_items_on_realm", using: :btree

  create_table "reports", force: :cascade do |t|
    t.integer  "item_id"
    t.integer  "reporter"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "kind"
    t.text     "comment"
  end

  add_index "reports", ["item_id"], name: "index_reports_on_item_id", using: :btree

end
