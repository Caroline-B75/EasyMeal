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

ActiveRecord::Schema[8.1].define(version: 2026_08_30_130000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "unaccent"

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

  create_table "favorite_recipes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "recipe_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["recipe_id"], name: "index_favorite_recipes_on_recipe_id"
    t.index ["user_id", "recipe_id"], name: "index_favorite_recipes_on_user_id_and_recipe_id", unique: true
    t.index ["user_id"], name: "index_favorite_recipes_on_user_id"
  end

  create_table "good_job_batches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "callback_priority"
    t.text "callback_queue_name"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "discarded_at"
    t.datetime "enqueued_at"
    t.datetime "finished_at"
    t.datetime "jobs_finished_at"
    t.text "on_discard"
    t.text "on_finish"
    t.text "on_success"
    t.jsonb "serialized_properties"
    t.datetime "updated_at", null: false
  end

  create_table "good_job_executions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "active_job_id", null: false
    t.datetime "created_at", null: false
    t.interval "duration"
    t.text "error"
    t.text "error_backtrace", array: true
    t.integer "error_event", limit: 2
    t.datetime "finished_at"
    t.text "job_class"
    t.uuid "process_id"
    t.text "queue_name"
    t.datetime "scheduled_at"
    t.jsonb "serialized_params"
    t.datetime "updated_at", null: false
    t.index ["active_job_id", "created_at"], name: "index_good_job_executions_on_active_job_id_and_created_at"
    t.index ["process_id", "created_at"], name: "index_good_job_executions_on_process_id_and_created_at"
  end

  create_table "good_job_processes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "lock_type", limit: 2
    t.jsonb "state"
    t.datetime "updated_at", null: false
  end

  create_table "good_job_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "key"
    t.datetime "updated_at", null: false
    t.jsonb "value"
    t.index ["key"], name: "index_good_job_settings_on_key", unique: true
  end

  create_table "good_jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "active_job_id"
    t.uuid "batch_callback_id"
    t.uuid "batch_id"
    t.text "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "cron_at"
    t.text "cron_key"
    t.text "error"
    t.integer "error_event", limit: 2
    t.integer "executions_count"
    t.datetime "finished_at"
    t.boolean "is_discrete"
    t.text "job_class"
    t.text "labels", array: true
    t.integer "lock_type", limit: 2
    t.datetime "locked_at"
    t.uuid "locked_by_id"
    t.datetime "performed_at"
    t.integer "priority"
    t.text "queue_name"
    t.uuid "retried_good_job_id"
    t.datetime "scheduled_at"
    t.jsonb "serialized_params"
    t.datetime "updated_at", null: false
    t.index ["active_job_id", "created_at"], name: "index_good_jobs_on_active_job_id_and_created_at"
    t.index ["batch_callback_id"], name: "index_good_jobs_on_batch_callback_id", where: "(batch_callback_id IS NOT NULL)"
    t.index ["batch_id"], name: "index_good_jobs_on_batch_id", where: "(batch_id IS NOT NULL)"
    t.index ["concurrency_key", "created_at"], name: "index_good_jobs_on_concurrency_key_and_created_at"
    t.index ["concurrency_key"], name: "index_good_jobs_on_concurrency_key_when_unfinished", where: "(finished_at IS NULL)"
    t.index ["created_at"], name: "index_good_jobs_on_created_at"
    t.index ["cron_key", "created_at"], name: "index_good_jobs_on_cron_key_and_created_at_cond", where: "(cron_key IS NOT NULL)"
    t.index ["cron_key", "cron_at"], name: "index_good_jobs_on_cron_key_and_cron_at_cond", unique: true, where: "(cron_key IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_jobs_on_finished_at_only", where: "(finished_at IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_on_discarded", order: :desc, where: "((finished_at IS NOT NULL) AND (error IS NOT NULL))"
    t.index ["id"], name: "index_good_jobs_on_unfinished_or_errored", where: "((finished_at IS NULL) OR (error IS NOT NULL))"
    t.index ["job_class"], name: "index_good_jobs_on_job_class"
    t.index ["labels"], name: "index_good_jobs_on_labels", where: "(labels IS NOT NULL)", using: :gin
    t.index ["locked_by_id"], name: "index_good_jobs_on_locked_by_id", where: "(locked_by_id IS NOT NULL)"
    t.index ["priority", "created_at"], name: "index_good_job_jobs_for_candidate_lookup", where: "(finished_at IS NULL)"
    t.index ["priority", "created_at"], name: "index_good_jobs_jobs_on_priority_created_at_when_unfinished", order: { priority: "DESC NULLS LAST" }, where: "(finished_at IS NULL)"
    t.index ["priority", "scheduled_at", "id"], name: "index_good_jobs_for_candidate_dequeue_unlocked", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["priority", "scheduled_at", "id"], name: "index_good_jobs_on_priority_scheduled_at_unfinished", where: "(finished_at IS NULL)"
    t.index ["priority", "scheduled_at"], name: "index_good_jobs_on_priority_scheduled_at_unfinished_unlocked", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["queue_name", "scheduled_at", "id"], name: "index_good_jobs_on_queue_name_priority_scheduled_at_unfinished", where: "(finished_at IS NULL)"
    t.index ["queue_name", "scheduled_at"], name: "index_good_jobs_on_queue_name_and_scheduled_at", where: "(finished_at IS NULL)"
    t.index ["queue_name"], name: "index_good_jobs_on_queue_name"
    t.index ["scheduled_at", "queue_name"], name: "index_good_jobs_on_scheduled_at_and_queue_name"
    t.index ["scheduled_at"], name: "index_good_jobs_on_scheduled_at", where: "(finished_at IS NULL)"
  end

  create_table "grocery_items", force: :cascade do |t|
    t.string "base_unit", null: false
    t.integer "category"
    t.boolean "checked", default: false, null: false
    t.datetime "created_at", null: false
    t.bigint "ingredient_id"
    t.bigint "menu_id", null: false
    t.string "name", null: false
    t.string "piece_label"
    t.string "piece_label_plural"
    t.decimal "piece_volume_ml", precision: 8, scale: 2
    t.decimal "piece_weight_g", precision: 8, scale: 2
    t.integer "position"
    t.decimal "previous_quantity_base", precision: 10, scale: 3
    t.decimal "quantity_base", precision: 10, scale: 3, null: false
    t.integer "source", default: 0, null: false
    t.integer "unit_group", null: false
    t.datetime "updated_at", null: false
    t.index ["ingredient_id"], name: "index_grocery_items_on_ingredient_id"
    t.index ["menu_id", "category"], name: "index_grocery_items_on_menu_id_and_category"
    t.index ["menu_id", "ingredient_id"], name: "index_grocery_items_on_menu_id_and_ingredient_id"
    t.index ["menu_id", "source"], name: "index_grocery_items_on_menu_id_and_source"
    t.index ["menu_id"], name: "index_grocery_items_on_menu_id"
  end

  create_table "ingredients", force: :cascade do |t|
    t.jsonb "aliases", default: {}
    t.string "base_unit", null: false
    t.integer "category", null: false
    t.datetime "created_at", null: false
    t.decimal "density_g_per_ml", precision: 6, scale: 3
    t.integer "density_source"
    t.string "name", null: false
    t.string "piece_label"
    t.string "piece_label_plural"
    t.decimal "piece_volume_ml", precision: 8, scale: 2
    t.decimal "piece_weight_g", precision: 8, scale: 2
    t.integer "season_months", default: [], array: true
    t.integer "unit_group", null: false
    t.datetime "updated_at", null: false
    t.index ["aliases"], name: "index_ingredients_on_aliases", using: :gin
    t.index ["category"], name: "index_ingredients_on_category"
    t.index ["name"], name: "index_ingredients_on_name", unique: true
    t.index ["name"], name: "index_ingredients_on_name_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["season_months"], name: "index_ingredients_on_season_months", using: :gin
  end

  create_table "menu_recipes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "day_of_week"
    t.string "meal_type"
    t.bigint "menu_id", null: false
    t.integer "number_of_people", null: false
    t.integer "position", default: 0, null: false
    t.bigint "recipe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["menu_id", "position"], name: "index_menu_recipes_on_menu_id_and_position"
    t.index ["menu_id", "recipe_id"], name: "index_menu_recipes_on_menu_id_and_recipe_id"
    t.index ["menu_id"], name: "index_menu_recipes_on_menu_id"
    t.index ["recipe_id"], name: "index_menu_recipes_on_recipe_id"
  end

  create_table "menus", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "default_people", default: 2, null: false
    t.integer "diet"
    t.string "name", null: false
    t.jsonb "requested_meal_counts", default: {}, null: false
    t.date "start_date"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["status"], name: "index_menus_on_status"
    t.index ["user_id", "start_date"], name: "index_menus_on_user_id_and_start_date"
    t.index ["user_id", "status"], name: "index_menus_on_user_id_and_status"
    t.index ["user_id"], name: "index_menus_on_user_id"
    t.index ["user_id"], name: "index_menus_on_user_id_unique_active", unique: true, where: "(status = 1)"
    t.index ["user_id"], name: "index_menus_on_user_id_unique_draft", unique: true, where: "(status = 0)"
  end

  create_table "preparations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "ingredient_id", null: false
    t.decimal "quantity_base", precision: 10, scale: 3, null: false
    t.bigint "recipe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["ingredient_id"], name: "index_preparations_on_ingredient_id"
    t.index ["recipe_id", "ingredient_id"], name: "index_preparations_on_recipe_id_and_ingredient_id", unique: true
    t.index ["recipe_id"], name: "index_preparations_on_recipe_id"
  end

  create_table "recipe_imports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.bigint "recipe_id"
    t.string "source_type", null: false
    t.string "source_url"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["recipe_id"], name: "index_recipe_imports_on_recipe_id"
    t.index ["user_id"], name: "index_recipe_imports_on_user_id"
  end

  create_table "recipe_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "recipe_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["recipe_id", "tag_id"], name: "index_recipe_tags_on_recipe_id_and_tag_id", unique: true
    t.index ["recipe_id"], name: "index_recipe_tags_on_recipe_id"
    t.index ["tag_id"], name: "index_recipe_tags_on_tag_id"
  end

  create_table "recipes", force: :cascade do |t|
    t.jsonb "ai_raw_data"
    t.string "appliance"
    t.integer "cook_time_minutes"
    t.datetime "created_at", null: false
    t.integer "default_servings", null: false
    t.text "description"
    t.integer "diet", null: false
    t.integer "difficulty"
    t.text "instructions"
    t.string "meal_types", default: [], null: false, array: true
    t.string "name", null: false
    t.integer "prep_time_minutes"
    t.integer "price"
    t.string "source_type"
    t.string "source_url"
    t.integer "status", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index "((COALESCE(prep_time_minutes, 0) + COALESCE(cook_time_minutes, 0)))", name: "index_recipes_on_total_time"
    t.index ["diet"], name: "index_recipes_on_diet"
    t.index ["difficulty"], name: "index_recipes_on_difficulty"
    t.index ["meal_types"], name: "index_recipes_on_meal_types", using: :gin
    t.index ["name"], name: "index_recipes_on_name"
    t.index ["name"], name: "index_recipes_on_name_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["status"], name: "index_recipes_on_status"
  end

  create_table "reviews", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.integer "rating", null: false
    t.bigint "recipe_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["rating"], name: "index_reviews_on_rating"
    t.index ["recipe_id"], name: "index_reviews_on_recipe_id"
    t.index ["user_id", "recipe_id"], name: "index_reviews_on_user_id_and_recipe_id", unique: true
    t.index ["user_id"], name: "index_reviews_on_user_id"
  end

  create_table "tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "tag_type"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
    t.index ["name"], name: "index_tags_on_name_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false
    t.datetime "created_at", null: false
    t.integer "default_diet", default: 0, null: false
    t.jsonb "default_meal_counts", default: {}, null: false
    t.integer "default_people", default: 2, null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name"
    t.string "gender"
    t.string "last_name"
    t.boolean "preferences_configured", default: false, null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.string "username"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "favorite_recipes", "recipes"
  add_foreign_key "favorite_recipes", "users"
  add_foreign_key "grocery_items", "ingredients"
  add_foreign_key "grocery_items", "menus"
  add_foreign_key "menu_recipes", "menus"
  add_foreign_key "menu_recipes", "recipes"
  add_foreign_key "menus", "users"
  add_foreign_key "preparations", "ingredients"
  add_foreign_key "preparations", "recipes"
  add_foreign_key "recipe_imports", "recipes"
  add_foreign_key "recipe_imports", "users"
  add_foreign_key "recipe_tags", "recipes"
  add_foreign_key "recipe_tags", "tags"
  add_foreign_key "reviews", "recipes"
  add_foreign_key "reviews", "users"
end
