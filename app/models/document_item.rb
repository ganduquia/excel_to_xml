class DocumentItem < ApplicationRecord
  TAX_STATUSES = %w[taxed excluded exempt].freeze

  belongs_to :tax_document
  belongs_to :tax_rate, optional: true

  validates :description,      presence: true
  validates :quantity,         numericality: { greater_than: 0 }
  validates :unit_price_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :discount_cents,   numericality: { greater_than_or_equal_to: 0 }
  validates :tax_status,       presence: true, inclusion: { in: TAX_STATUSES }
  validate  :taxed_item_requires_tax_rate
  validate  :discount_cannot_exceed_subtotal

  before_save :compute_subtotal

  def taxed?    = tax_status == "taxed"
  def excluded? = tax_status == "excluded"
  def exempt?   = tax_status == "exempt"

  def gross_cents
    (quantity * unit_price_cents).round
  end

  def net_cents
    gross_cents - discount_cents
  end

  private

  def compute_subtotal
    self.subtotal_cents = net_cents
    self.tax_amount_cents = if taxed? && tax_rate
      (net_cents * tax_rate.rate / 100.0).round
    else
      0
    end
  end

  def taxed_item_requires_tax_rate
    return unless tax_status == "taxed"
    errors.add(:tax_rate, "es requerida para ítems gravados") if tax_rate_id.blank?
  end

  def discount_cannot_exceed_subtotal
    return unless unit_price_cents && quantity && discount_cents
    errors.add(:discount_cents, "no puede superar el valor bruto del ítem") if discount_cents > gross_cents
  end
end
