class CreateReconciliationItemChanges < ActiveRecord::Migration[7.1]
  def change
    create_table :reconciliation_item_changes do |t|
      t.references :reconciliation_item, null: false, foreign_key: true
      t.string :field_name
      t.text   :old_value
      t.text   :new_value
      t.string :changed_by
      t.timestamps
    end

    add_index :reconciliation_item_changes, [:reconciliation_item_id, :created_at],
              name: "idx_recon_changes_item_date"
  end
end
