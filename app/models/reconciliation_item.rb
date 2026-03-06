class ReconciliationItem < ApplicationRecord
  REVIEW_STATUSES      = %w[pending reviewed].freeze
  DEFERRED_TAX_CLASSES = %w[asset liability none].freeze

  belongs_to :reconciliation_period
  has_many   :reconciliation_item_changes, dependent: :destroy

  validates :account_code,   presence: true
  validates :review_status,  inclusion: { in: REVIEW_STATUSES }
  validates :deferred_tax_classification, inclusion: { in: DEFERRED_TAX_CLASSES }
  validates :adjustment_comment, presence: true,
            length: { minimum: 10, message: "debe tener al menos 10 caracteres" },
            if: -> { fiscal_adjustment_cents.to_i != 0 }
  validate  :no_adjustment_when_no_fiscal_effect

  before_save :recalculate!

  # ── Cálculo principal ────────────────────────────────────────────────────

  def recalculate!
    self.account_class = account_code.to_s[0]

    # Si la cuenta no ha sido revisada aún, no calcular
    if has_fiscal_effect.nil?
      self.fiscal_balance_cents         = nil
      self.temporary_difference_cents   = 0
      self.applies_deferred_tax         = false
      self.deferred_tax_amount_cents    = 0
      self.deferred_tax_classification  = "none"
      return
    end

    adj = fiscal_adjustment_cents.to_i

    if has_fiscal_effect == false
      self.fiscal_adjustment_cents = 0
      adj = 0
    end

    self.fiscal_balance_cents       = closing_balance_cents.to_i + adj
    self.temporary_difference_cents = closing_balance_cents.to_i - fiscal_balance_cents.to_i

    if %w[1 2].include?(account_class)
      self.applies_deferred_tax        = true
      self.deferred_tax_rate_snapshot  = reconciliation_period.deferred_tax_rate
      self.deferred_tax_amount_cents   = (temporary_difference_cents.abs * deferred_tax_rate_snapshot).round
      self.deferred_tax_classification = classify_deferred_tax
    else
      self.applies_deferred_tax        = false
      self.deferred_tax_amount_cents   = 0
      self.deferred_tax_classification = "none"
    end
  end

  # ── Helpers de presentación ──────────────────────────────────────────────

  def review_pending?
    review_status == "pending"
  end

  def fiscal_adjustment_pesos
    fiscal_adjustment_cents.to_i / 100.0
  end

  def fiscal_balance_pesos
    fiscal_balance_cents.to_i / 100.0
  end

  def closing_balance_pesos
    closing_balance_cents.to_i / 100.0
  end

  def temporary_difference_pesos
    temporary_difference_cents.to_i / 100.0
  end

  def deferred_tax_amount_pesos
    deferred_tax_amount_cents.to_i / 100.0
  end

  private

  def no_adjustment_when_no_fiscal_effect
    if has_fiscal_effect == false && fiscal_adjustment_cents.to_i != 0
      errors.add(:fiscal_adjustment_cents, "debe ser cero cuando la cuenta no tiene efecto fiscal")
    end
  end

  def classify_deferred_tax
    return "none" if temporary_difference_cents.zero?

    diff = temporary_difference_cents
    case account_class
    when "1"
      # Activo: diff > 0 → valor contable > fiscal → pasivo ID
      diff > 0 ? "liability" : "asset"
    when "2"
      # Pasivo (naturaleza crédito, saldo negativo): diff < 0 → pasivo contable > fiscal → activo ID
      diff < 0 ? "asset" : "liability"
    else
      "none"
    end
  end
end
