class CreateDocumentItems < ActiveRecord::Migration[7.1]
  def change
    create_table :document_items do |t|
      t.references :tax_document, null: false, foreign_key: true
      t.string  :description,      null: false
      t.decimal :quantity,         null: false, precision: 14, scale: 4, default: "1.0"
      t.bigint  :unit_price_cents, null: false
      t.bigint  :discount_cents,   null: false, default: 0
      # taxed | excluded | exempt
      # taxed    -> aplica IVA a la tarifa de tax_rate
      # excluded -> no genera IVA (Arts. 424, 476 ET)
      # exempt   -> tarifa 0%, se declara (Art. 477 ET)
      t.string  :tax_status,       null: false
      t.references :tax_rate, foreign_key: true
      t.bigint  :subtotal_cents,   null: false, default: 0
      t.bigint  :tax_amount_cents, null: false, default: 0
      t.timestamps
    end

    add_index :document_items, :tax_status
  end
end
