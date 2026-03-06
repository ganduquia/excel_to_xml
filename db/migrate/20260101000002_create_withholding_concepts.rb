class CreateWithholdingConcepts < ActiveRecord::Migration[7.1]
  def change
    create_table :withholding_concepts do |t|
      t.string  :code,           null: false
      t.string  :name,           null: false
      t.decimal :rate,           null: false, precision: 8, scale: 4
      t.bigint  :min_amount_cents, null: false, default: 0
      # declarante | no_declarante | gran_contribuyente | todos
      t.string  :taxpayer_type,  null: false
      # bruto = sobre subtotal antes de IVA | neto = sobre subtotal menos costos
      t.string  :base_type,      null: false, default: "bruto"
      t.date    :effective_from, null: false
      t.date    :effective_to
      t.boolean :active,         null: false, default: true
      t.text    :notes
      t.timestamps
    end

    add_index :withholding_concepts, [:code, :taxpayer_type]
    add_index :withholding_concepts, [:active, :effective_from]
  end
end
