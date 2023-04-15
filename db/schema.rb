# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2023_03_01_010000) do
  create_table "activity_logs", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "user_id"
    t.string "activity", default: "", null: false
    t.string "note"
    t.string "ip_address", default: "", null: false
    t.text "user_agent"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "categories", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "election_id", null: false
    t.string "image"
    t.integer "sort_order"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "pinned", default: false
    t.integer "category_group", default: 1
  end

  create_table "category_translations", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "category_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "name"
    t.index ["category_id"], name: "index_category_translations_on_category_id"
    t.index ["locale"], name: "index_category_translations_on_locale"
  end

  create_table "code_batches", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "election_id", null: false
    t.integer "user_id", null: false
    t.integer "status"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "codes", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "code_batch_id", null: false
    t.string "code", default: "", null: false
    t.integer "status"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["code_batch_id", "code"], name: "index_codes_on_code_batch_id_and_code", unique: true
  end

  create_table "election_users", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "election_id", null: false
    t.integer "user_id", null: false
    t.integer "status", null: false
    t.boolean "active", default: true
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "elections", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "name", default: "", null: false
    t.string "description"
    t.string "slug", default: "", null: false
    t.integer "budget"
    t.integer "max_n_projects"
    t.string "time_zone"
    t.text "config_yaml", size: :long
    t.boolean "allow_admins_to_update_election", default: true, null: false
    t.boolean "allow_admins_to_see_voter_data", default: true, null: false
    t.boolean "allow_admins_to_see_exact_results", default: true, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "real_election", default: true, null: false
    t.text "remarks"
    t.index ["slug"], name: "index_elections_on_slug", unique: true
  end

  create_table "locations", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "election_id", null: false
    t.string "name"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "project_translations", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "project_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "title"
    t.text "description"
    t.text "details"
    t.string "address"
    t.string "partner"
    t.string "committee"
    t.string "video_url"
    t.text "image_description"
    t.index ["locale"], name: "index_project_translations_on_locale"
    t.index ["project_id"], name: "index_project_translations_on_project_id"
  end

  create_table "projects", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "election_id", null: false
    t.integer "category_id"
    t.string "number"
    t.integer "cost"
    t.text "map_geometry"
    t.string "image"
    t.integer "external_vote_count"
    t.integer "sort_order"
    t.text "data"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "adjustable_cost", default: false
    t.integer "cost_min", default: 0
    t.integer "cost_step", default: 1
    t.boolean "uses_slider", default: false
  end

  create_table "users", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "username", default: "", null: false
    t.string "password_digest"
    t.string "salt"
    t.boolean "is_superadmin", default: false, null: false
    t.boolean "confirmed", default: false, null: false
    t.string "confirmation_id"
    t.datetime "confirmation_id_created_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "visitors", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "ip_address"
    t.text "user_agent"
    t.text "referrer"
    t.text "url"
    t.datetime "created_at", precision: nil
    t.string "method", null: false
  end

  create_table "vote_approvals", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "voter_id", null: false
    t.integer "project_id", null: false
    t.integer "cost"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "rank", default: 1
    t.index ["project_id"], name: "index_vote_approvals_on_project_id"
    t.index ["voter_id"], name: "index_vote_approvals_on_voter_id"
  end

  create_table "vote_comparisons", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "voter_id", null: false
    t.integer "first_project_id", null: false
    t.integer "first_project_cost"
    t.integer "second_project_id", null: false
    t.integer "second_project_cost"
    t.integer "result", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["voter_id"], name: "index_vote_comparisons_on_voter_id"
  end

  create_table "vote_knapsacks", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "voter_id", null: false
    t.integer "project_id", null: false
    t.integer "cost"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["project_id"], name: "index_vote_knapsacks_on_project_id"
    t.index ["voter_id"], name: "index_vote_knapsacks_on_voter_id"
  end

  create_table "vote_plusminuses", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "voter_id", null: false
    t.integer "project_id", null: false
    t.integer "plusminus", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["project_id"], name: "index_vote_plusminuses_on_project_id"
    t.index ["voter_id"], name: "index_vote_plusminuses_on_voter_id"
  end

  create_table "vote_rankings", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "voter_id", null: false
    t.bigint "project_id", null: false
    t.integer "cost"
    t.integer "rank"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["project_id"], name: "index_vote_rankings_on_project_id"
    t.index ["voter_id"], name: "index_vote_rankings_on_voter_id"
  end

  create_table "vote_tokens", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "voter_id", null: false
    t.bigint "project_id", null: false
    t.integer "cost"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["project_id"], name: "index_vote_tokens_on_project_id"
    t.index ["voter_id"], name: "index_vote_tokens_on_voter_id"
  end

  create_table "voter_registration_records", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "election_id", null: false
    t.integer "user_id"
    t.integer "voter_id"
    t.text "data"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "voters", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "election_id", null: false
    t.integer "location_id"
    t.string "authentication_method", default: "", null: false
    t.string "authentication_id", default: "", null: false
    t.string "confirmation_code"
    t.datetime "confirmation_code_created_at", precision: nil
    t.string "ip_address"
    t.text "user_agent"
    t.string "stage"
    t.boolean "void", default: false
    t.text "data"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["election_id", "authentication_method", "authentication_id"], name: "index_voters_on_election_id_and_authentication", unique: true
  end

end
