class CreateTaxLines < ActiveRecord::Migration[7.1]
  def change
    create_table :tax_lines do |t|
      t.references :tax_document,        null: false, foreign_key: true
      # iva | retefuente | reteiva | reteica
      t.string  :tax_type,               null: false
      t.references :withholding_concept, foreign_key: true
      # Snapshot de la tasa en el momento del cálculo (trazabilidad auditada)
      t.decimal :rate_snapshot,          null: false, precision: 8, scale: 4
      t.bigint  :base_cents,             null: false
      t.bigint  :amount_cents,           null: false
      # charge = suma al total (IVA en ventas)
      # credit = resta del total (retenciones)
      t.string  :direction,              null: false
      t.datetime :calculated_at,         null: false
      # JSON con detalle completo del cálculo para auditoría
      t.text    :calculation_detail
      t.timestamps
    end

    add_index :tax_lines, [:tax_document_id, :tax_type]
    add_index :tax_lines, :tax_type
  end
end
