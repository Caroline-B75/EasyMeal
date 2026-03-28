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

ActiveRecord::Schema[7.2].define(version: 2026_02_01_100001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "favorite_recipes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "recipe_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recipe_id"], name: "index_favorite_recipes_on_recipe_id"
    t.index ["user_id", "recipe_id"], name: "index_favorite_recipes_on_user_id_and_recipe_id", unique: true
    t.index ["user_id"], name: "index_favorite_recipes_on_user_id"
  end

  create_table "ingredients", force: :cascade do |t|
    t.string "name", null: false
    t.integer "category", null: false
    t.integer "unit_group", null: false
    t.string "base_unit", null: false
    t.integer "season_months", default: [], array: true
    t.jsonb "aliases", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["aliases"], name: "index_ingredients_on_aliases", using: :gin
    t.index ["category"], name: "index_ingredients_on_category"
    t.index ["name"], name: "index_ingredients_on_name", unique: true
  end

  create_table "menu_recipes", force: :cascade do |t|
    t.bigint "menu_id", null: false
    t.bigint "recipe_id", null: false
    t.integer "number_of_people", null: false
    t.string "meal_type"
    t.date "scheduled_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["menu_id", "recipe_id"], name: "index_menu_recipes_on_menu_id_and_recipe_id"
    t.index ["menu_id", "scheduled_date"], name: "index_menu_recipes_on_menu_id_and_scheduled_date"
    t.index ["menu_id"], name: "index_menu_recipes_on_menu_id"
    t.index ["recipe_id"], name: "index_menu_recipes_on_recipe_id"
  end

  create_table "menus", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "user_id", null: false
    t.date "start_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "start_date"], name: "index_menus_on_user_id_and_start_date"
    t.index ["user_id"], name: "index_menus_on_user_id"
  end

  create_table "preparations", force: :cascade do |t|
    t.bigint "recipe_id", null: false
    t.bigint "ingredient_id", null: false
    t.decimal "quantity_base", precision: 10, scale: 3, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ingredient_id"], name: "index_preparations_on_ingredient_id"
    t.index ["recipe_id", "ingredient_id"], name: "index_preparations_on_recipe_id_and_ingredient_id", unique: true
    t.index ["recipe_id"], name: "index_preparations_on_recipe_id"
  end

  create_table "recipe_tags", force: :cascade do |t|
    t.bigint "recipe_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recipe_id", "tag_id"], name: "index_recipe_tags_on_recipe_id_and_tag_id", unique: true
    t.index ["recipe_id"], name: "index_recipe_tags_on_recipe_id"
    t.index ["tag_id"], name: "index_recipe_tags_on_tag_id"
  end

  create_table "recipes", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.text "instructions"
    t.integer "default_servings", null: false
    t.integer "prep_time_minutes"
    t.integer "cook_time_minutes"
    t.integer "difficulty"
    t.integer "price"
    t.integer "diet", null: false
    t.string "appliance"
    t.string "source_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["diet"], name: "index_recipes_on_diet"
    t.index ["difficulty"], name: "index_recipes_on_difficulty"
    t.index ["name"], name: "index_recipes_on_name"
  end

  create_table "reviews", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "recipe_id", null: false
    t.integer "rating", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["rating"], name: "index_reviews_on_rating"
    t.index ["recipe_id"], name: "index_reviews_on_recipe_id"
    t.index ["user_id", "recipe_id"], name: "index_reviews_on_user_id_and_recipe_id", unique: true
    t.index ["user_id"], name: "index_reviews_on_user_id"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name", null: false
    t.integer "tag_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "username"
    t.string "first_name"
    t.string "last_name"
    t.boolean "admin", default: false
    t.string "gender"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "favorite_recipes", "recipes"
  add_foreign_key "favorite_recipes", "users"
  add_foreign_key "menu_recipes", "menus"
  add_foreign_key "menu_recipes", "recipes"
  add_foreign_key "menus", "users"
  add_foreign_key "preparations", "ingredients"
  add_foreign_key "preparations", "recipes"
  add_foreign_key "recipe_tags", "recipes"
  add_foreign_key "recipe_tags", "tags"
  add_foreign_key "reviews", "recipes"
  add_foreign_key "reviews", "users"
end
