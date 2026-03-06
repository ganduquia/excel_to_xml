class WithholdingConcept < ApplicationRecord
  TAXPAYER_TYPES = %w[declarante no_declarante gran_contribuyente todos].freeze
  BASE_TYPES     = %w[bruto neto].freeze

  has_many :tax_lines

  validates :code,           presence: true
  validates :name,           presence: true
  validates :rate,           presence: true, numericality: { greater_than_or_equal_to: 0, less_than: 100 }
  validates :taxpayer_type,  presence: true, inclusion: { in: TAXPAYER_TYPES }
  validates :base_type,      presence: true, inclusion: { in: BASE_TYPES }
  validates :effective_from, presence: true
  validates :min_amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validate  :effective_to_after_effective_from

  scope :active,  -> { where(active: true) }

  # Conceptos vigentes para un tipo de contribuyente en una fecha dada
  def self.applicable_on(date, taxpayer_type:)
    where(active: true)
      .where(taxpayer_type: [taxpayer_type, "todos"])
      .where("effective_from <= ?", date)
      .where("effective_to IS NULL OR effective_to >= ?", date)
      .order(:code)
  end

  def min_amount
    min_amount_cents / 100.0
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
