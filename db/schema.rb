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

ActiveRecord::Schema.define(version: 20160503040605) do

  create_table "activity_logs", force: :cascade do |t|
    t.integer  "user_id"
    t.string   "activity",   null: false
    t.string   "note"
    t.string   "ip_address", null: false
    t.text     "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "categories", force: :cascade do |t|
    t.integer  "election_id",                    null: false
    t.string   "image"
    t.integer  "sort_order"
    t.boolean  "pinned",         default: false
    t.integer  "category_group", default: 1
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
  end

  create_table "category_translations", force: :cascade do |t|
    t.integer  "category_id", null: false
    t.string   "locale",      null: false
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
    t.string   "name"
  end

  add_index "category_translations", ["category_id"], name: "index_category_translations_on_category_id"
  add_index "category_translations", ["locale"], name: "index_category_translations_on_locale"

  create_table "code_batches", force: :cascade do |t|
    t.integer  "election_id", null: false
    t.integer  "user_id",     null: false
    t.integer  "status"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  create_table "codes", force: :cascade do |t|
    t.integer  "code_batch_id", null: false
    t.string   "code",          null: false
    t.integer  "status"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

  add_index "codes", ["code_batch_id", "code"], name: "index_codes_on_code_batch_id_and_code", unique: true

  create_table "election_users", force: :cascade do |t|
    t.integer  "election_id",                null: false
    t.integer  "user_id",                    null: false
    t.integer  "status",                     null: false
    t.boolean  "active",      default: true
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
  end

  create_table "elections", force: :cascade do |t|
    t.string   "name",                                              null: false
    t.string   "description"
    t.string   "slug",                                              null: false
    t.integer  "budget"
    t.string   "time_zone"
    t.text     "config_yaml"
    t.boolean  "allow_admins_to_update_election",   default: false, null: false
    t.boolean  "allow_admins_to_see_voter_data",    default: false, null: false
    t.boolean  "allow_admins_to_see_exact_results", default: false, null: false
    t.datetime "created_at",                                        null: false
    t.datetime "updated_at",                                        null: false
  end

  add_index "elections", ["slug"], name: "index_elections_on_slug", unique: true

  create_table "locations", force: :cascade do |t|
    t.integer  "election_id", null: false
    t.string   "name"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  create_table "project_translations", force: :cascade do |t|
    t.integer  "project_id",  null: false
    t.string   "locale",      null: false
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
    t.string   "title"
    t.string   "short_title"
    t.text     "description"
    t.text     "details"
    t.string   "address"
    t.string   "partner"
    t.string   "committee"
    t.string   "video_url"
  end

  add_index "project_translations", ["locale"], name: "index_project_translations_on_locale"
  add_index "project_translations", ["project_id"], name: "index_project_translations_on_project_id"

  create_table "projects", force: :cascade do |t|
    t.integer  "election_id",                         null: false
    t.integer  "category_id"
    t.string   "number"
    t.integer  "cost"
    t.boolean  "adjustable_cost",     default: false
    t.integer  "cost_min",            default: 0
    t.integer  "cost_step",           default: 1
    t.string   "map_geometry"
    t.string   "image"
    t.integer  "external_vote_count"
    t.integer  "sort_order"
    t.text     "data"
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
    t.boolean  "uses_slider",         default: false
  end

  create_table "users", force: :cascade do |t|
    t.string   "username",                                   null: false
    t.string   "password_digest"
    t.string   "salt"
    t.boolean  "is_superadmin",              default: false, null: false
    t.boolean  "confirmed",                  default: false, null: false
    t.string   "confirmation_id"
    t.datetime "confirmation_id_created_at"
    t.datetime "created_at",                                 null: false
    t.datetime "updated_at",                                 null: false
  end

  add_index "users", ["username"], name: "index_users_on_username", unique: true

  create_table "vote_approvals", force: :cascade do |t|
    t.integer  "voter_id",               null: false
    t.integer  "project_id",             null: false
    t.integer  "cost"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
    t.integer  "rank",       default: 1
  end

  add_index "vote_approvals", ["project_id"], name: "index_vote_approvals_on_project_id"

  create_table "vote_comparisons", force: :cascade do |t|
    t.integer  "voter_id",            null: false
    t.integer  "first_project_id",    null: false
    t.integer  "first_project_cost"
    t.integer  "second_project_id",   null: false
    t.integer  "second_project_cost"
    t.integer  "result",              null: false
    t.datetime "created_at",          null: false
    t.datetime "updated_at",          null: false
  end

  create_table "vote_knapsacks", force: :cascade do |t|
    t.integer  "voter_id",   null: false
    t.integer  "project_id", null: false
    t.integer  "cost"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "vote_knapsacks", ["project_id"], name: "index_vote_knapsacks_on_project_id"

  create_table "vote_plusminuses", force: :cascade do |t|
    t.integer  "voter_id",   null: false
    t.integer  "project_id", null: false
    t.integer  "plusminus",  null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "vote_plusminuses", ["project_id"], name: "index_vote_plusminuses_on_project_id"

  create_table "voter_registration_records", force: :cascade do |t|
    t.integer  "election_id", null: false
    t.integer  "user_id",     null: false
    t.integer  "voter_id",    null: false
    t.text     "data"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  create_table "voters", force: :cascade do |t|
    t.integer  "election_id",                                  null: false
    t.integer  "location_id"
    t.string   "authentication_method",                        null: false
    t.string   "authentication_id",                            null: false
    t.string   "confirmation_code"
    t.datetime "confirmation_code_created_at"
    t.string   "ip_address"
    t.text     "user_agent"
    t.string   "stage"
    t.boolean  "void",                         default: false, null: false
    t.text     "data"
    t.datetime "created_at",                                   null: false
    t.datetime "updated_at",                                   null: false
  end

  add_index "voters", ["election_id", "authentication_method", "authentication_id"], name: "index_voters_on_election_id_and_authentication", unique: true

end
