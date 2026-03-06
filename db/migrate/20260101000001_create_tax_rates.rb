class CreateTaxRates < ActiveRecord::Migration[7.1]
  def change
    create_table :tax_rates do |t|
      t.string  :name,           null: false
      t.string  :tax_type,       null: false  # iva, reteiva, reteica
      t.decimal :rate,           null: false, precision: 8, scale: 4
      t.date    :effective_from, null: false
      t.date    :effective_to
      t.boolean :active,         null: false, default: true
      t.text    :notes
      t.timestamps
    end

    add_index :tax_rates, [:tax_type, :active]
    add_index :tax_rates, [:tax_type, :effective_from, :effective_to]
  end
end
