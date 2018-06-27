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
    t.integer  "user_id",    limit: 4
    t.string   "activity",   limit: 255,   null: false
    t.string   "note",       limit: 255
    t.string   "ip_address", limit: 255,   null: false
    t.text     "user_agent", limit: 65535
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
  end

  create_table "categories", force: :cascade do |t|
    t.integer  "election_id",    limit: 4,                   null: false
    t.string   "image",          limit: 255
    t.integer  "sort_order",     limit: 4
    t.boolean  "pinned",                     default: false
    t.integer  "category_group", limit: 4,   default: 1
    t.datetime "created_at",                                 null: false
    t.datetime "updated_at",                                 null: false
  end

  create_table "category_translations", force: :cascade do |t|
    t.integer  "category_id", limit: 4,   null: false
    t.string   "locale",      limit: 255, null: false
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
    t.string   "name",        limit: 255
  end

  add_index "category_translations", ["category_id"], name: "index_category_translations_on_category_id", using: :btree
  add_index "category_translations", ["locale"], name: "index_category_translations_on_locale", using: :btree

  create_table "code_batches", force: :cascade do |t|
    t.integer  "election_id", limit: 4, null: false
    t.integer  "user_id",     limit: 4, null: false
    t.integer  "status",      limit: 4
    t.datetime "created_at",            null: false
    t.datetime "updated_at",            null: false
  end

  create_table "codes", force: :cascade do |t|
    t.integer  "code_batch_id", limit: 4,   null: false
    t.string   "code",          limit: 255, null: false
    t.integer  "status",        limit: 4
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
  end

  add_index "codes", ["code_batch_id", "code"], name: "index_codes_on_code_batch_id_and_code", unique: true, using: :btree

  create_table "election_users", force: :cascade do |t|
    t.integer  "election_id", limit: 4,                null: false
    t.integer  "user_id",     limit: 4,                null: false
    t.integer  "status",      limit: 4,                null: false
    t.boolean  "active",                default: true
    t.datetime "created_at",                           null: false
    t.datetime "updated_at",                           null: false
  end

  create_table "elections", force: :cascade do |t|
    t.string   "name",                              limit: 255,                   null: false
    t.string   "description",                       limit: 255
    t.string   "slug",                              limit: 255,                   null: false
    t.integer  "budget",                            limit: 4
    t.string   "time_zone",                         limit: 255
    t.text     "config_yaml",                       limit: 65535
    t.boolean  "allow_admins_to_update_election",                 default: false, null: false
    t.boolean  "allow_admins_to_see_voter_data",                  default: false, null: false
    t.boolean  "allow_admins_to_see_exact_results",               default: false, null: false
    t.datetime "created_at",                                                      null: false
    t.datetime "updated_at",                                                      null: false
  end

  add_index "elections", ["slug"], name: "index_elections_on_slug", unique: true, using: :btree

  create_table "locations", force: :cascade do |t|
    t.integer  "election_id", limit: 4,   null: false
    t.string   "name",        limit: 255
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
  end

  create_table "project_translations", force: :cascade do |t|
    t.integer  "project_id",  limit: 4,     null: false
    t.string   "locale",      limit: 255,   null: false
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.string   "title",       limit: 255
    t.string   "short_title", limit: 255
    t.text     "description", limit: 65535
    t.text     "details",     limit: 65535
    t.string   "address",     limit: 255
    t.string   "partner",     limit: 255
    t.string   "committee",   limit: 255
    t.string   "video_url",   limit: 255
  end

  add_index "project_translations", ["locale"], name: "index_project_translations_on_locale", using: :btree
  add_index "project_translations", ["project_id"], name: "index_project_translations_on_project_id", using: :btree

  create_table "projects", force: :cascade do |t|
    t.integer  "election_id",         limit: 4,                     null: false
    t.integer  "category_id",         limit: 4
    t.string   "number",              limit: 255
    t.integer  "cost",                limit: 4
    t.boolean  "adjustable_cost",                   default: false
    t.integer  "cost_min",            limit: 4,     default: 0
    t.integer  "cost_step",           limit: 4,     default: 1
    t.string   "map_geometry",        limit: 255
    t.string   "image",               limit: 255
    t.integer  "external_vote_count", limit: 4
    t.integer  "sort_order",          limit: 4
    t.text     "data",                limit: 65535
    t.datetime "created_at",                                        null: false
    t.datetime "updated_at",                                        null: false
    t.boolean  "uses_slider",                       default: false
  end

  create_table "users", force: :cascade do |t|
    t.string   "username",                   limit: 255,                 null: false
    t.string   "password_digest",            limit: 255
    t.string   "salt",                       limit: 255
    t.boolean  "is_superadmin",                          default: false, null: false
    t.boolean  "confirmed",                              default: false, null: false
    t.string   "confirmation_id",            limit: 255
    t.datetime "confirmation_id_created_at"
    t.datetime "created_at",                                             null: false
    t.datetime "updated_at",                                             null: false
  end

  add_index "users", ["username"], name: "index_users_on_username", unique: true, using: :btree

  create_table "vote_approvals", force: :cascade do |t|
    t.integer  "voter_id",   limit: 4,             null: false
    t.integer  "project_id", limit: 4,             null: false
    t.integer  "cost",       limit: 4
    t.datetime "created_at",                       null: false
    t.datetime "updated_at",                       null: false
    t.integer  "rank",       limit: 4, default: 1
  end

  add_index "vote_approvals", ["project_id"], name: "index_vote_approvals_on_project_id", using: :btree
  add_index "vote_approvals", ["voter_id"], name: "index_vote_approvals_on_voter_id", using: :btree

  create_table "vote_comparisons", force: :cascade do |t|
    t.integer  "voter_id",            limit: 4, null: false
    t.integer  "first_project_id",    limit: 4, null: false
    t.integer  "first_project_cost",  limit: 4
    t.integer  "second_project_id",   limit: 4, null: false
    t.integer  "second_project_cost", limit: 4
    t.integer  "result",              limit: 4, null: false
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
  end

  add_index "vote_comparisons", ["voter_id"], name: "index_vote_comparisons_on_voter_id", using: :btree

  create_table "vote_knapsacks", force: :cascade do |t|
    t.integer  "voter_id",   limit: 4, null: false
    t.integer  "project_id", limit: 4, null: false
    t.integer  "cost",       limit: 4
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
  end

  add_index "vote_knapsacks", ["project_id"], name: "index_vote_knapsacks_on_project_id", using: :btree
  add_index "vote_knapsacks", ["voter_id"], name: "index_vote_knapsacks_on_voter_id", using: :btree

  create_table "vote_plusminuses", force: :cascade do |t|
    t.integer  "voter_id",   limit: 4, null: false
    t.integer  "project_id", limit: 4, null: false
    t.integer  "plusminus",  limit: 4, null: false
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
  end

  add_index "vote_plusminuses", ["project_id"], name: "index_vote_plusminuses_on_project_id", using: :btree
  add_index "vote_plusminuses", ["voter_id"], name: "index_vote_plusminuses_on_voter_id", using: :btree

  create_table "voter_registration_records", force: :cascade do |t|
    t.integer  "election_id", limit: 4,     null: false
    t.integer  "user_id",     limit: 4
    t.integer  "voter_id",    limit: 4
    t.text     "data",        limit: 65535
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
  end

  create_table "voters", force: :cascade do |t|
    t.integer  "election_id",                  limit: 4,                     null: false
    t.integer  "location_id",                  limit: 4
    t.string   "authentication_method",        limit: 255,                   null: false
    t.string   "authentication_id",            limit: 255,                   null: false
    t.string   "confirmation_code",            limit: 255
    t.datetime "confirmation_code_created_at"
    t.string   "ip_address",                   limit: 255
    t.text     "user_agent",                   limit: 65535
    t.string   "stage",                        limit: 255
    t.boolean  "void",                                       default: false, null: false
    t.text     "data",                         limit: 65535
    t.datetime "created_at",                                                 null: false
    t.datetime "updated_at",                                                 null: false
  end

  add_index "voters", ["election_id", "authentication_method", "authentication_id"], name: "index_voters_on_election_id_and_authentication", unique: true, using: :btree

end
