class CreateReconciliationItems < ActiveRecord::Migration[7.1]
  def change
    create_table :reconciliation_items do |t|
      t.references :reconciliation_period, null: false, foreign_key: true

      # Datos del balance de comprobación (importados del Excel)
      t.string :account_type
      t.string :account_code,           null: false
      t.string :account_name
      t.string :account_class,          limit: 1
      t.bigint :opening_balance_cents,  default: 0, null: false
      t.bigint :debit_cents,            default: 0, null: false
      t.bigint :credit_cents,           default: 0, null: false
      t.bigint :closing_balance_cents,  default: 0, null: false

      # Campos de conciliación (editados por el usuario)
      t.boolean :has_fiscal_effect                       # null = sin revisar
      t.bigint  :fiscal_adjustment_cents, default: 0    # con signo
      t.text    :adjustment_comment
      t.text    :exclusion_reason
      t.string  :review_status, default: "pending", null: false
      t.string  :reviewed_by
      t.datetime :reviewed_at

      # Campos calculados automáticamente
      t.bigint  :fiscal_balance_cents
      t.bigint  :temporary_difference_cents,  default: 0
      t.boolean :applies_deferred_tax,        default: false
      t.decimal :deferred_tax_rate_snapshot,  precision: 5, scale: 4
      t.bigint  :deferred_tax_amount_cents,   default: 0
      t.string  :deferred_tax_classification, default: "none"

      t.timestamps
    end

    add_index :reconciliation_items, [:reconciliation_period_id, :account_code], unique: true,
              name: "idx_recon_items_period_code"
    add_index :reconciliation_items, [:reconciliation_period_id, :review_status],
              name: "idx_recon_items_period_status"
    add_index :reconciliation_items, [:reconciliation_period_id, :account_class],
              name: "idx_recon_items_period_class"
  end
end
