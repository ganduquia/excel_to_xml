class TaxRate < ApplicationRecord
  TAX_TYPES = %w[iva reteiva reteica].freeze

  has_many :document_items

  validates :name,           presence: true
  validates :tax_type,       presence: true, inclusion: { in: TAX_TYPES }
  validates :rate,           presence: true, numericality: { greater_than_or_equal_to: 0, less_than: 100 }
  validates :effective_from, presence: true
  validate  :effective_to_after_effective_from

  scope :active,    -> { where(active: true) }
  scope :iva,       -> { where(tax_type: "iva") }
  scope :reteiva,   -> { where(tax_type: "reteiva") }

  # Devuelve la tarifa vigente para un tipo e impuesto en una fecha dada
  def self.active_on(date, tax_type:)
    where(tax_type: tax_type, active: true)
      .where("effective_from <= ?", date)
      .where("effective_to IS NULL OR effective_to >= ?", date)
      .order(effective_from: :desc)
      .first
  end

  def rate_percent
    "#{rate}%"
  end

  private

  def effective_to_after_effective_from
    return unless effective_from && effective_to
    errors.add(:effective_to, "debe ser posterior a effective_from") if effective_to < effective_from
  end
end
