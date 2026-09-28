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

ActiveRecord::Schema[8.1].define(version: 2026_09_11_133255) do
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

  create_table "categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_categories_on_slug", unique: true
  end

  create_table "categories_companies", id: false, force: :cascade do |t|
    t.integer "category_id", null: false
    t.integer "company_id", null: false
    t.index ["category_id", "company_id"], name: "index_categories_companies_on_category_id_and_company_id"
    t.index ["company_id", "category_id"], name: "index_categories_companies_on_company_id_and_category_id", unique: true
  end

  create_table "cities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ibge_code"
    t.string "name"
    t.integer "searches_count", default: 0, null: false
    t.string "slug"
    t.integer "state_id", null: false
    t.datetime "updated_at", null: false
    t.index ["ibge_code"], name: "index_cities_on_ibge_code"
    t.index ["state_id", "slug"], name: "index_cities_on_state_id_and_slug", unique: true
    t.index ["state_id"], name: "index_cities_on_state_id"
  end

  create_table "companies", force: :cascade do |t|
    t.string "business_hours"
    t.decimal "capital_social"
    t.string "card_brand"
    t.string "card_last4"
    t.integer "city_id", null: false
    t.datetime "claim_expiration_date"
    t.string "claim_status", default: "unclaimed", null: false
    t.datetime "claimed_at"
    t.string "cnae_principal"
    t.text "cnae_secundarios"
    t.string "cnpj"
    t.string "company_size"
    t.string "complement"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "document_proof_url"
    t.datetime "document_submitted_at"
    t.string "email"
    t.string "establishment_type"
    t.string "geocode_precision"
    t.boolean "is_claimed", default: false, null: false
    t.float "latitude"
    t.string "legal_name"
    t.string "legal_nature"
    t.string "logo_url"
    t.float "longitude"
    t.integer "neighborhood_id"
    t.string "number"
    t.date "opening_date"
    t.string "phone_1"
    t.boolean "phone_1_whatsapp", default: false
    t.string "phone_2"
    t.boolean "phone_2_whatsapp", default: false
    t.string "plan", default: "free", null: false
    t.string "removal_request_email"
    t.string "removal_request_name"
    t.boolean "removal_requested", default: false, null: false
    t.string "selfie_proof_url"
    t.string "slug"
    t.integer "state_id", null: false
    t.string "status"
    t.date "status_date"
    t.string "street"
    t.string "stripe_customer_id"
    t.string "stripe_payment_method_id"
    t.string "trade_name"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.integer "views_count", default: 0, null: false
    t.string "website"
    t.string "zip_code"
    t.index ["city_id", "status", "deleted_at", "is_claimed", "updated_at"], name: "idx_companies_city_search_opt"
    t.index ["city_id"], name: "index_companies_on_city_id"
    t.index ["claim_status", "removal_requested"], name: "idx_companies_claim_status_removal_requested"
    t.index ["claim_status"], name: "index_companies_on_claim_status"
    t.index ["cnae_principal"], name: "index_companies_on_cnae_principal"
    t.index ["cnpj"], name: "index_companies_on_cnpj", unique: true
    t.index ["deleted_at", "claim_status", "updated_at"], name: "idx_companies_deleted_claim_updated"
    t.index ["deleted_at", "updated_at"], name: "idx_companies_deleted_updated"
    t.index ["deleted_at"], name: "index_companies_on_deleted_at"
    t.index ["email"], name: "index_companies_on_email"
    t.index ["geocode_precision"], name: "index_companies_on_geocode_precision"
    t.index ["neighborhood_id", "status", "deleted_at", "is_claimed", "updated_at"], name: "idx_companies_neighborhood_search_opt"
    t.index ["neighborhood_id"], name: "index_companies_on_neighborhood_id"
    t.index ["removal_requested"], name: "index_companies_on_removal_requested"
    t.index ["slug"], name: "index_companies_on_slug"
    t.index ["state_id", "status", "deleted_at", "is_claimed", "updated_at"], name: "idx_companies_state_search_opt"
    t.index ["state_id"], name: "index_companies_on_state_id"
    t.index ["status"], name: "index_companies_on_status"
    t.index ["stripe_customer_id"], name: "index_companies_on_stripe_customer_id"
    t.index ["user_id"], name: "index_companies_on_user_id"
  end

  create_table "company_email_opt_outs", force: :cascade do |t|
    t.bigint "company_id"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.text "feedback"
    t.string "reason"
    t.string "token", null: false
    t.datetime "unsubscribed_at"
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_company_email_opt_outs_on_company_id"
    t.index ["email"], name: "index_company_email_opt_outs_on_email"
    t.index ["token"], name: "index_company_email_opt_outs_on_token", unique: true
  end

  create_table "company_outreach_logs", force: :cascade do |t|
    t.string "campaign_name", default: "profile_presentation", null: false
    t.datetime "clicked_at"
    t.integer "company_id", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "sent_at", null: false
    t.string "status", default: "sent", null: false
    t.datetime "updated_at", null: false
    t.index ["clicked_at"], name: "index_company_outreach_logs_on_clicked_at"
    t.index ["company_id", "campaign_name"], name: "index_company_outreach_logs_on_company_id_and_campaign_name"
    t.index ["company_id"], name: "index_company_outreach_logs_on_company_id"
    t.index ["email", "campaign_name"], name: "index_company_outreach_logs_on_email_and_campaign_name"
    t.index ["email"], name: "index_company_outreach_logs_on_email"
  end

  create_table "contact_reveal_logs", force: :cascade do |t|
    t.integer "company_id", null: false
    t.string "contact_type"
    t.datetime "created_at", null: false
    t.boolean "disclaimer_accepted", default: true, null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id"
    t.index ["company_id"], name: "index_contact_reveal_logs_on_company_id"
    t.index ["user_id"], name: "index_contact_reveal_logs_on_user_id"
  end

  create_table "contacts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.text "message"
    t.string "name"
    t.string "subject"
    t.datetime "updated_at", null: false
  end

  create_table "favorites", force: :cascade do |t|
    t.integer "company_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["company_id"], name: "index_favorites_on_company_id"
    t.index ["user_id", "company_id"], name: "index_favorites_on_user_id_and_company_id", unique: true
    t.index ["user_id"], name: "index_favorites_on_user_id"
  end

  create_table "neighborhoods", force: :cascade do |t|
    t.integer "city_id", null: false
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "searches_count", default: 0, null: false
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["city_id", "slug"], name: "index_neighborhoods_on_city_id_and_slug", unique: true
    t.index ["city_id"], name: "index_neighborhoods_on_city_id"
  end

  create_table "partners", force: :cascade do |t|
    t.string "age_range"
    t.integer "company_id", null: false
    t.datetime "created_at", null: false
    t.string "document"
    t.date "entry_date"
    t.string "name"
    t.string "person_type"
    t.string "qualification"
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_partners_on_company_id"
  end

  create_table "reviews", force: :cascade do |t|
    t.text "comment"
    t.integer "company_id", null: false
    t.datetime "created_at", null: false
    t.integer "rating", null: false
    t.string "reviewer_name", null: false
    t.text "tags"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["company_id"], name: "index_reviews_on_company_id"
    t.index ["user_id", "company_id"], name: "index_reviews_on_user_id_and_company_id", unique: true
    t.index ["user_id"], name: "index_reviews_on_user_id"
  end

  create_table "states", force: :cascade do |t|
    t.string "acronym"
    t.datetime "created_at", null: false
    t.string "name"
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["acronym"], name: "index_states_on_acronym", unique: true
    t.index ["slug"], name: "index_states_on_slug", unique: true
  end

  create_table "stripe_charges", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, default: "0.0", null: false
    t.integer "company_id", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "brl", null: false
    t.text "failure_message"
    t.decimal "fee", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "net", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "paid_at"
    t.datetime "refunded_at"
    t.integer "sales_commission_id"
    t.string "status", default: "succeeded", null: false
    t.string "stripe_charge_id"
    t.string "stripe_customer_id"
    t.string "stripe_invoice_id"
    t.integer "subscription_id"
    t.datetime "updated_at", null: false
    t.index ["company_id", "status"], name: "index_stripe_charges_on_company_id_and_status"
    t.index ["company_id"], name: "index_stripe_charges_on_company_id"
    t.index ["status"], name: "index_stripe_charges_on_status"
    t.index ["stripe_charge_id"], name: "index_stripe_charges_on_stripe_charge_id", unique: true
    t.index ["stripe_invoice_id"], name: "index_stripe_charges_on_stripe_invoice_id"
    t.index ["subscription_id"], name: "index_stripe_charges_on_subscription_id"
  end

  create_table "stripe_prices", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.decimal "amount_cents", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "brl", null: false
    t.string "interval", default: "year", null: false
    t.integer "interval_count", default: 12, null: false
    t.string "name"
    t.string "stripe_price_id"
    t.integer "stripe_product_id", null: false
    t.datetime "updated_at", null: false
    t.index ["stripe_price_id"], name: "index_stripe_prices_on_stripe_price_id"
    t.index ["stripe_product_id"], name: "index_stripe_prices_on_stripe_product_id"
  end

  create_table "stripe_products", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "slug", null: false
    t.string "stripe_product_id"
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_stripe_products_on_slug", unique: true
    t.index ["stripe_product_id"], name: "index_stripe_products_on_stripe_product_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.datetime "accepted_terms_at"
    t.datetime "canceled_at"
    t.integer "company_id", null: false
    t.datetime "created_at", null: false
    t.datetime "current_period_end"
    t.datetime "current_period_start"
    t.datetime "ends_at"
    t.string "ip_address"
    t.string "status", default: "active", null: false
    t.integer "stripe_price_id", null: false
    t.string "stripe_subscription_id"
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_subscriptions_on_company_id"
    t.index ["status"], name: "index_subscriptions_on_status"
    t.index ["stripe_price_id"], name: "index_subscriptions_on_stripe_price_id"
    t.index ["stripe_subscription_id"], name: "index_subscriptions_on_stripe_subscription_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name"
    t.string "phone"
    t.string "provider"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role", default: "client", null: false
    t.datetime "terms_accepted_at"
    t.string "uid"
    t.string "unconfirmed_email"
    t.datetime "updated_at", null: false
    t.datetime "welcome_email_sent_at"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "cities", "states"
  add_foreign_key "companies", "cities"
  add_foreign_key "companies", "neighborhoods"
  add_foreign_key "companies", "states"
  add_foreign_key "companies", "users"
  add_foreign_key "company_outreach_logs", "companies"
  add_foreign_key "contact_reveal_logs", "companies"
  add_foreign_key "contact_reveal_logs", "users"
  add_foreign_key "favorites", "companies"
  add_foreign_key "favorites", "users"
  add_foreign_key "neighborhoods", "cities"
  add_foreign_key "partners", "companies"
  add_foreign_key "reviews", "companies"
  add_foreign_key "reviews", "users"
  add_foreign_key "stripe_charges", "companies"
  add_foreign_key "stripe_charges", "subscriptions"
  add_foreign_key "stripe_prices", "stripe_products"
  add_foreign_key "subscriptions", "companies"
  add_foreign_key "subscriptions", "stripe_prices"
end
