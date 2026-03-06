class ReconciliationPeriod < ApplicationRecord
  STATUSES = %w[draft in_review approved closed].freeze

  has_many :reconciliation_items, dependent: :destroy

  validates :name,             presence: true
  validates :fiscal_year,      presence: true, numericality: { only_integer: true }
  validates :deferred_tax_rate, presence: true,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 0.4 }
  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(fiscal_year: :desc, created_at: :desc) }

  def items_count
    reconciliation_items.count
  end

  def pending_count
    reconciliation_items.where(review_status: "pending").count
  end

  def reviewed_count
    reconciliation_items.where(review_status: "reviewed").count
  end

  def completion_percentage
    return 0 if items_count.zero?
    (reviewed_count.to_f / items_count * 100).round
  end

  def approvable?
    items_count > 0 && pending_count.zero?
  end

  def editable?
    %w[draft in_review].include?(status)
  end

  def approved?
    %w[approved closed].include?(status)
  end

  def total_deferred_tax_asset_cents
    reconciliation_items.where(deferred_tax_classification: "asset").sum(:deferred_tax_amount_cents)
  end

  def total_deferred_tax_liability_cents
    reconciliation_items.where(deferred_tax_classification: "liability").sum(:deferred_tax_amount_cents)
  end

  def total_adjustment_cents
    reconciliation_items.sum(:fiscal_adjustment_cents)
  end
end
