class CreateTaxDocuments < ActiveRecord::Migration[7.1]
  def change
    create_table :tax_documents do |t|
      # invoice_sale | invoice_purchase | debit_note | credit_note
      t.string  :document_type,            null: false
      t.string  :number,                   null: false
      t.date    :issue_date,               null: false
      t.string  :third_party_nit,          null: false
      t.string  :third_party_name,         null: false
      # declarante | no_declarante | gran_contribuyente
      # autorretenedor | regimen_simple | no_responsable_iva
      t.string  :taxpayer_type,            null: false
      t.boolean :is_withholding_agent,     null: false, default: false
      t.boolean :third_party_autoretainer, null: false, default: false
      # draft | active | cancelled
      t.string  :status,                   null: false, default: "draft"
      t.bigint  :subtotal_cents,           null: false, default: 0
      t.bigint  :total_iva_cents,          null: false, default: 0
      t.bigint  :total_withholding_cents,  null: false, default: 0
      t.bigint  :total_cents,              null: false, default: 0
      t.string  :currency,                 null: false, default: "COP"
      # Para notas crédito/débito: referencia al documento origen
      t.references :original_document, foreign_key: { to_table: :tax_documents }
      t.text    :notes
      t.timestamps
    end

    add_index :tax_documents, :number
    add_index :tax_documents, [:document_type, :status]
    add_index :tax_documents, :issue_date
  end
end
