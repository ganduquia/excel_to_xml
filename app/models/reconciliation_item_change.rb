class ReconciliationItemChange < ApplicationRecord
  belongs_to :reconciliation_item

  validates :field_name, presence: true
end
