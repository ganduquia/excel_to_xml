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

ActiveRecord::Schema[7.1].define(version: 2026_03_06_220003) do
  create_table "document_items", force: :cascade do |t|
    t.integer "tax_document_id", null: false
    t.string "description", null: false
    t.decimal "quantity", precision: 14, scale: 4, default: "1.0", null: false
    t.bigint "unit_price_cents", null: false
    t.bigint "discount_cents", default: 0, null: false
    t.string "tax_status", null: false
    t.integer "tax_rate_id"
    t.bigint "subtotal_cents", default: 0, null: false
    t.bigint "tax_amount_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tax_document_id"], name: "index_document_items_on_tax_document_id"
    t.index ["tax_rate_id"], name: "index_document_items_on_tax_rate_id"
    t.index ["tax_status"], name: "index_document_items_on_tax_status"
  end

  create_table "reconciliation_item_changes", force: :cascade do |t|
    t.integer "reconciliation_item_id", null: false
    t.string "field_name"
    t.text "old_value"
    t.text "new_value"
    t.string "changed_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reconciliation_item_id", "created_at"], name: "idx_recon_changes_item_date"
    t.index ["reconciliation_item_id"], name: "index_reconciliation_item_changes_on_reconciliation_item_id"
  end

  create_table "reconciliation_items", force: :cascade do |t|
    t.integer "reconciliation_period_id", null: false
    t.string "account_type"
    t.string "account_code", null: false
    t.string "account_name"
    t.string "account_class", limit: 1
    t.bigint "opening_balance_cents", default: 0, null: false
    t.bigint "debit_cents", default: 0, null: false
    t.bigint "credit_cents", default: 0, null: false
    t.bigint "closing_balance_cents", default: 0, null: false
    t.boolean "has_fiscal_effect"
    t.bigint "fiscal_adjustment_cents", default: 0
    t.text "adjustment_comment"
    t.text "exclusion_reason"
    t.string "review_status", default: "pending", null: false
    t.string "reviewed_by"
    t.datetime "reviewed_at"
    t.bigint "fiscal_balance_cents"
    t.bigint "temporary_difference_cents", default: 0
    t.boolean "applies_deferred_tax", default: false
    t.decimal "deferred_tax_rate_snapshot", precision: 5, scale: 4
    t.bigint "deferred_tax_amount_cents", default: 0
    t.string "deferred_tax_classification", default: "none"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reconciliation_period_id", "account_class"], name: "idx_recon_items_period_class"
    t.index ["reconciliation_period_id", "account_code"], name: "idx_recon_items_period_code", unique: true
    t.index ["reconciliation_period_id", "review_status"], name: "idx_recon_items_period_status"
    t.index ["reconciliation_period_id"], name: "index_reconciliation_items_on_reconciliation_period_id"
  end

  create_table "reconciliation_periods", force: :cascade do |t|
    t.string "name", null: false
    t.integer "fiscal_year", null: false
    t.string "company_nit"
    t.string "company_name"
    t.date "start_date"
    t.date "end_date"
    t.decimal "deferred_tax_rate", precision: 5, scale: 4, default: "0.35", null: false
    t.string "status", default: "draft", null: false
    t.string "created_by"
    t.string "approved_by"
    t.datetime "approved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fiscal_year", "status"], name: "index_reconciliation_periods_on_fiscal_year_and_status"
  end

  create_table "tax_documents", force: :cascade do |t|
    t.string "document_type", null: false
    t.string "number", null: false
    t.date "issue_date", null: false
    t.string "third_party_nit", null: false
    t.string "third_party_name", null: false
    t.string "taxpayer_type", null: false
    t.boolean "is_withholding_agent", default: false, null: false
    t.boolean "third_party_autoretainer", default: false, null: false
    t.string "status", default: "draft", null: false
    t.bigint "subtotal_cents", default: 0, null: false
    t.bigint "total_iva_cents", default: 0, null: false
    t.bigint "total_withholding_cents", default: 0, null: false
    t.bigint "total_cents", default: 0, null: false
    t.string "currency", default: "COP", null: false
    t.integer "original_document_id"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "withholding_concept_id"
    t.index ["document_type", "status"], name: "index_tax_documents_on_document_type_and_status"
    t.index ["issue_date"], name: "index_tax_documents_on_issue_date"
    t.index ["number"], name: "index_tax_documents_on_number"
    t.index ["original_document_id"], name: "index_tax_documents_on_original_document_id"
    t.index ["withholding_concept_id"], name: "index_tax_documents_on_withholding_concept_id"
  end

  create_table "tax_lines", force: :cascade do |t|
    t.integer "tax_document_id", null: false
    t.string "tax_type", null: false
    t.integer "withholding_concept_id"
    t.decimal "rate_snapshot", precision: 8, scale: 4, null: false
    t.bigint "base_cents", null: false
    t.bigint "amount_cents", null: false
    t.string "direction", null: false
    t.datetime "calculated_at", null: false
    t.text "calculation_detail"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tax_document_id", "tax_type"], name: "index_tax_lines_on_tax_document_id_and_tax_type"
    t.index ["tax_document_id"], name: "index_tax_lines_on_tax_document_id"
    t.index ["tax_type"], name: "index_tax_lines_on_tax_type"
    t.index ["withholding_concept_id"], name: "index_tax_lines_on_withholding_concept_id"
  end

  create_table "tax_rates", force: :cascade do |t|
    t.string "name", null: false
    t.string "tax_type", null: false
    t.decimal "rate", precision: 8, scale: 4, null: false
    t.date "effective_from", null: false
    t.date "effective_to"
    t.boolean "active", default: true, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tax_type", "active"], name: "index_tax_rates_on_tax_type_and_active"
    t.index ["tax_type", "effective_from", "effective_to"], name: "idx_on_tax_type_effective_from_effective_to_22ac0a5aec"
  end

  create_table "withholding_concepts", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.decimal "rate", precision: 8, scale: 4, null: false
    t.bigint "min_amount_cents", default: 0, null: false
    t.string "taxpayer_type", null: false
    t.string "base_type", default: "bruto", null: false
    t.date "effective_from", null: false
    t.date "effective_to"
    t.boolean "active", default: true, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active", "effective_from"], name: "index_withholding_concepts_on_active_and_effective_from"
    t.index ["code", "taxpayer_type"], name: "index_withholding_concepts_on_code_and_taxpayer_type"
  end

  add_foreign_key "document_items", "tax_documents"
  add_foreign_key "document_items", "tax_rates"
  add_foreign_key "reconciliation_item_changes", "reconciliation_items"
  add_foreign_key "reconciliation_items", "reconciliation_periods"
  add_foreign_key "tax_documents", "tax_documents", column: "original_document_id"
  add_foreign_key "tax_documents", "withholding_concepts"
  add_foreign_key "tax_lines", "tax_documents"
  add_foreign_key "tax_lines", "withholding_concepts"
end
