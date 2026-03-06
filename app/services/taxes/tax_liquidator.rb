module Taxes
  # Orquestador principal. Valida, calcula y persiste todos los impuestos
  # de un TaxDocument en una sola transacción atómica.
  class TaxLiquidator
    attr_reader :document

    def initialize(document)
      @document = document
    end

    def self.call(document)
      new(document).call
    end

    def call
      validator = DocumentValidator.new(document)
      unless validator.valid?
        return failure_result(validator.errors)
      end

      iva_lines         = IvaCalculator.new(document).call
      withholding_lines = WithholdingCalculator.new(document).call

      ActiveRecord::Base.transaction do
        document.tax_lines.destroy_all

        (iva_lines + withholding_lines).each(&:save!)

        totals = compute_totals(iva_lines, withholding_lines)

        document.update!(
          subtotal_cents:          document.document_items.sum(&:subtotal_cents),
          total_iva_cents:         totals[:total_iva],
          total_withholding_cents: totals[:total_withholding],
          total_cents:             totals[:total_to_pay]
        )
      end

      success_result(iva_lines, withholding_lines)
    rescue ActiveRecord::RecordInvalid => e
      failure_result([e.message])
    end

    private

    def compute_totals(iva_lines, withholding_lines)
      subtotal         = document.document_items.sum(&:subtotal_cents)
      total_iva        = iva_lines.sum(&:amount_cents)
      total_withholding = withholding_lines.sum(&:amount_cents)
      total_to_pay     = subtotal + total_iva - total_withholding

      { subtotal:, total_iva:, total_withholding:, total_to_pay: }
    end

    def success_result(iva_lines, withholding_lines)
      subtotal          = document.subtotal_cents
      total_iva         = document.total_iva_cents
      total_withholding = document.total_withholding_cents

      {
        success:          true,
        errors:           [],
        subtotal_cents:   subtotal,
        total_iva_cents:  total_iva,
        total_withholding_cents: total_withholding,
        total_to_pay_cents: subtotal + total_iva - total_withholding,
        iva_lines:        iva_lines,
        withholding_lines: withholding_lines,
        summary: {
          subtotal:         format_cop(subtotal),
          iva:              format_cop(total_iva),
          retenciones:      format_cop(total_withholding),
          total_a_pagar:    format_cop(subtotal + total_iva - total_withholding)
        }
      }
    end

    def failure_result(errors)
      { success: false, errors:, iva_lines: [], withholding_lines: [] }
    end

    def format_cop(cents)
      "$#{format('%.0f', cents / 100.0)} COP"
    end
  end
end
