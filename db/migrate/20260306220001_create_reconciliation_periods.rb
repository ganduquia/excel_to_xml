class CreateReconciliationPeriods < ActiveRecord::Migration[7.1]
  def change
    create_table :reconciliation_periods do |t|
      t.string  :name,              null: false
      t.integer :fiscal_year,       null: false
      t.string  :company_nit
      t.string  :company_name
      t.date    :start_date
      t.date    :end_date
      t.decimal :deferred_tax_rate, precision: 5, scale: 4, default: 0.35, null: false
      t.string  :status,            default: "draft", null: false
      t.string  :created_by
      t.string  :approved_by
      t.datetime :approved_at
      t.timestamps
    end

    add_index :reconciliation_periods, [:fiscal_year, :status]
  end
end
