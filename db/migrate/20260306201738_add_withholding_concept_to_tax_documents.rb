class AddWithholdingConceptToTaxDocuments < ActiveRecord::Migration[7.1]
  def change
    add_reference :tax_documents, :withholding_concept, null: true,
                  foreign_key: { to_table: :withholding_concepts }
  end
end
