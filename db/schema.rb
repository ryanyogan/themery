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

ActiveRecord::Schema[8.1].define(version: 2026_08_31_154635) do
  create_table "action_mailbox_inbound_emails", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "message_checksum", null: false
    t.string "message_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["message_id", "message_checksum"], name: "index_action_mailbox_inbound_emails_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "fetch_events", force: :cascade do |t|
    t.string "client_hash", null: false
    t.datetime "created_at", null: false
    t.string "pack_name", null: false
    t.integer "theme_id", null: false
    t.index ["theme_id", "created_at"], name: "index_fetch_events_on_theme_id_and_created_at"
    t.index ["theme_id"], name: "index_fetch_events_on_theme_id"
  end

  create_table "reviews", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.integer "theme_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["theme_id"], name: "index_reviews_on_theme_id"
    t.index ["user_id", "theme_id"], name: "index_reviews_on_user_id_and_theme_id", unique: true
    t.index ["user_id"], name: "index_reviews_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "stars", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "theme_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.string "voter_key", null: false
    t.index ["theme_id", "voter_key"], name: "index_stars_on_theme_id_and_voter_key", unique: true
    t.index ["theme_id"], name: "index_stars_on_theme_id"
    t.index ["user_id"], name: "index_stars_on_user_id"
  end

  create_table "submissions", force: :cascade do |t|
    t.text "changelog"
    t.datetime "created_at", null: false
    t.json "error_report", default: [], null: false
    t.string "kind", null: false
    t.string "source_url"
    t.string "state", default: "received", null: false
    t.integer "theme_id"
    t.string "theme_name", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.integer "version_id"
    t.index ["theme_id"], name: "index_submissions_on_theme_id"
    t.index ["user_id"], name: "index_submissions_on_user_id"
    t.index ["version_id"], name: "index_submissions_on_version_id"
  end

  create_table "themes", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.integer "installs_count", default: 0, null: false
    t.string "mode"
    t.string "mood"
    t.string "name", null: false
    t.string "source_url"
    t.integer "stars_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "updates_count", default: 0, null: false
    t.string "upstream_commit"
    t.integer "user_id", null: false
    t.index ["category"], name: "index_themes_on_category"
    t.index ["mood"], name: "index_themes_on_mood"
    t.index ["name"], name: "index_themes_on_name", unique: true
    t.index ["user_id"], name: "index_themes_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.datetime "email_verified_at"
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "approved_at"
    t.text "changelog"
    t.json "colors"
    t.datetime "created_at", null: false
    t.json "manifest", default: {}, null: false
    t.string "mode"
    t.json "normalization_ledger", default: [], null: false
    t.integer "number", null: false
    t.string "pack_name"
    t.text "review_note"
    t.string "state", default: "pending", null: false
    t.integer "theme_id", null: false
    t.datetime "updated_at", null: false
    t.index ["theme_id", "number"], name: "index_versions_on_theme_id_and_number", unique: true
    t.index ["theme_id"], name: "index_versions_on_theme_id"
    t.index ["theme_id"], name: "index_versions_on_theme_id_pending", unique: true, where: "state = 'pending'"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "fetch_events", "themes"
  add_foreign_key "reviews", "themes"
  add_foreign_key "reviews", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "stars", "themes"
  add_foreign_key "stars", "users"
  add_foreign_key "submissions", "themes"
  add_foreign_key "submissions", "users"
  add_foreign_key "submissions", "versions"
  add_foreign_key "themes", "users"
  add_foreign_key "versions", "themes"
end
