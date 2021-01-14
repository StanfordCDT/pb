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

ActiveRecord::Schema.define(version: 2019_04_16_100000) do

  create_table "activity_logs", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "user_id"
    t.string "activity", null: false
    t.string "note"
    t.string "ip_address", null: false
    t.text "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_activity_logs_on_user_id"
  end

  create_table "categories", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "election_id", null: false
    t.string "image"
    t.integer "sort_order"
    t.boolean "pinned", default: false
    t.integer "category_group", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["election_id"], name: "index_categories_on_election_id"
  end

  create_table "category_translations", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "category_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.index ["category_id"], name: "index_category_translations_on_category_id"
    t.index ["locale"], name: "index_category_translations_on_locale"
  end

  create_table "code_batches", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "election_id", null: false
    t.bigint "user_id", null: false
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["election_id"], name: "index_code_batches_on_election_id"
    t.index ["user_id"], name: "index_code_batches_on_user_id"
  end

  create_table "codes", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "code_batch_id", null: false
    t.string "code", null: false
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code_batch_id", "code"], name: "index_codes_on_code_batch_id_and_code", unique: true
    t.index ["code_batch_id"], name: "index_codes_on_code_batch_id"
  end

  create_table "election_users", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "election_id", null: false
    t.bigint "user_id", null: false
    t.integer "status", null: false
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["election_id"], name: "index_election_users_on_election_id"
    t.index ["user_id"], name: "index_election_users_on_user_id"
  end

  create_table "elections", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "description"
    t.string "slug", null: false
    t.integer "budget"
    t.string "time_zone"
    t.text "config_yaml"
    t.boolean "allow_admins_to_update_election", default: true, null: false
    t.boolean "allow_admins_to_see_voter_data", default: true, null: false
    t.boolean "allow_admins_to_see_exact_results", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "real_election", default: true, null: false
    t.text "remarks"
    t.index ["slug"], name: "index_elections_on_slug", unique: true
  end

  create_table "locations", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "election_id", null: false
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["election_id"], name: "index_locations_on_election_id"
  end

  create_table "project_translations", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "project_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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

  create_table "projects", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "election_id", null: false
    t.bigint "category_id"
    t.string "number"
    t.integer "cost"
    t.boolean "adjustable_cost", default: false
    t.integer "cost_min", default: 0
    t.integer "cost_step", default: 1
    t.text "map_geometry"
    t.string "image"
    t.integer "external_vote_count"
    t.integer "sort_order"
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "uses_slider", default: false
    t.index ["category_id"], name: "index_projects_on_category_id"
    t.index ["election_id"], name: "index_projects_on_election_id"
  end

  create_table "users", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "username", null: false
    t.string "password_digest"
    t.string "salt"
    t.boolean "is_superadmin", default: false, null: false
    t.boolean "confirmed", default: false, null: false
    t.string "confirmation_id"
    t.datetime "confirmation_id_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "visitors", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "ip_address", null: false
    t.text "user_agent"
    t.text "referrer"
    t.text "url"
    t.datetime "created_at", null: false
    t.string "method", null: false
  end

  create_table "vote_approvals", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "voter_id", null: false
    t.bigint "project_id", null: false
    t.integer "cost"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "rank", default: 1
    t.index ["project_id"], name: "index_vote_approvals_on_project_id"
    t.index ["voter_id"], name: "index_vote_approvals_on_voter_id"
  end

  create_table "vote_comparisons", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "voter_id", null: false
    t.integer "first_project_id", null: false
    t.integer "first_project_cost"
    t.integer "second_project_id", null: false
    t.integer "second_project_cost"
    t.integer "result", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["voter_id"], name: "index_vote_comparisons_on_voter_id"
  end

  create_table "vote_knapsacks", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "voter_id", null: false
    t.bigint "project_id", null: false
    t.integer "cost"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_vote_knapsacks_on_project_id"
    t.index ["voter_id"], name: "index_vote_knapsacks_on_voter_id"
  end

  create_table "vote_plusminuses", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "voter_id", null: false
    t.bigint "project_id", null: false
    t.integer "plusminus", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_vote_plusminuses_on_project_id"
    t.index ["voter_id"], name: "index_vote_plusminuses_on_voter_id"
  end

  create_table "vote_rankings", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "voter_id", null: false
    t.bigint "project_id", null: false
    t.integer "cost"
    t.integer "rank"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_vote_rankings_on_project_id"
    t.index ["voter_id"], name: "index_vote_rankings_on_voter_id"
  end

  create_table "voter_registration_records", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "election_id", null: false
    t.bigint "user_id"
    t.bigint "voter_id"
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["election_id"], name: "index_voter_registration_records_on_election_id"
    t.index ["user_id"], name: "index_voter_registration_records_on_user_id"
    t.index ["voter_id"], name: "index_voter_registration_records_on_voter_id"
  end

  create_table "voters", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "election_id", null: false
    t.bigint "location_id"
    t.string "authentication_method", null: false
    t.string "authentication_id", null: false
    t.string "confirmation_code"
    t.datetime "confirmation_code_created_at"
    t.string "ip_address"
    t.text "user_agent"
    t.string "stage"
    t.boolean "void", default: false, null: false
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["election_id", "authentication_method", "authentication_id"], name: "index_voters_on_election_id_and_authentication", unique: true
    t.index ["election_id"], name: "index_voters_on_election_id"
    t.index ["location_id"], name: "index_voters_on_location_id"
  end

end
