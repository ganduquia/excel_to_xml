module Taxes
  # Después de conciliar un Auxiliar, recalcula fiscal balance, diferencia temporaria
  # e impuesto diferido de todos sus niveles superiores (SubCuenta → Cuenta → Grupo → Clase).
  class ReconciliationPropagator
    # Longitudes estándar del PUC colombiano para niveles superiores al Auxiliar
    PARENT_LENGTHS = [6, 4, 2, 1].freeze

    def initialize(period, auxiliar_item)
      @period   = period
      @auxiliar = auxiliar_item
    end

    def call
      parent_codes = find_parent_codes
      parent_codes.each { |code| recalculate_parent(code) }
    end

    private

    # Encuentra los códigos padre existentes en este período
    def find_parent_codes
      code = @auxiliar.account_code.to_s
      candidates = PARENT_LENGTHS
        .map { |len| code[0...len] if code.length > len }
        .compact.uniq

      @period.reconciliation_items
             .where.not(account_type: "Auxiliar")
             .where(account_code: candidates)
             .order(Arel.sql("LENGTH(account_code) DESC"))
             .pluck(:account_code)
    end

    # Recalcula los valores de un nivel padre sumando todos sus Auxiliar hijos
    def recalculate_parent(parent_code)
      parent = @period.reconciliation_items.find_by(account_code: parent_code)
      return unless parent

      # Todos los Auxiliares que pertenecen a este padre
      children = @period.reconciliation_items
                        .where(account_type: "Auxiliar")
                        .where("account_code LIKE ?", "#{parent_code}%")

      total = children.count
      return if total.zero?

      # Saldo fiscal: usa fiscal_balance si ya fue conciliado, saldo contable si no
      fiscal_bal = children.sum(
        "CASE WHEN fiscal_balance_cents IS NOT NULL THEN fiscal_balance_cents ELSE closing_balance_cents END"
      )

      temp_diff       = children.sum(:temporary_difference_cents)
      adj             = children.sum(:fiscal_adjustment_cents)
      deferred_amount = children.sum(:deferred_tax_amount_cents)

      # Clasificación agregada del impuesto diferido
      asset_amount = children.where(deferred_tax_classification: "asset").sum(:deferred_tax_amount_cents)
      liab_amount  = children.where(deferred_tax_classification: "liability").sum(:deferred_tax_amount_cents)

      classif = if asset_amount > 0 && liab_amount.zero?
        "asset"
      elsif liab_amount > 0 && asset_amount.zero?
        "liability"
      else
        "none"
      end

      parent.update_columns(
        fiscal_balance_cents:        fiscal_bal,
        temporary_difference_cents:  temp_diff,
        fiscal_adjustment_cents:     adj,
        deferred_tax_amount_cents:   deferred_amount,
        deferred_tax_classification: classif,
        applies_deferred_tax:        deferred_amount > 0,
        updated_at:                  Time.current
      )
    end
  end
end
