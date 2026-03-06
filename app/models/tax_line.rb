class TaxLine < ApplicationRecord
  TAX_TYPES  = %w[iva retefuente reteiva reteica].freeze
  DIRECTIONS = %w[charge credit].freeze

  belongs_to :tax_document
  belongs_to :withholding_concept, optional: true

  validates :tax_type,      presence: true, inclusion: { in: TAX_TYPES }
  validates :rate_snapshot, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :base_cents,    presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :amount_cents,  presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :direction,     presence: true, inclusion: { in: DIRECTIONS }
  validates :calculated_at, presence: true
  validate  :retefuente_requires_concept

  scope :charges, -> { where(direction: "charge") }
  scope :credits, -> { where(direction: "credit") }
  scope :iva,     -> { where(tax_type: "iva") }
  scope :retefuente, -> { where(tax_type: "retefuente") }

  def calculation_detail_parsed
    return {} if calculation_detail.blank?
    JSON.parse(calculation_detail)
  rescue JSON::ParserError
    {}
  end

  def charge?  = direction == "charge"
  def credit?  = direction == "credit"

  private

  def retefuente_requires_concept
    return unless tax_type.in?(%w[retefuente reteiva reteica])
    errors.add(:withholding_concept, "es requerido para retenciones") if withholding_concept_id.blank?
  end
end
