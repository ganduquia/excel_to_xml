module Taxes
  class WithholdingCalculator
    # UVT 2026 según Resolución DIAN (publicada dic. 2025)
    # Valor: $53,206 COP — verificar con Resolución oficial si hay ajuste
    UVT_2026 = 5_320_600  # en centavos

    attr_reader :document, :policy

    def initialize(document)
      @document = document
      @policy   = TaxApplicabilityPolicy.new(document)
    end

    # Devuelve array de TaxLine (no persistidos) con todas las retenciones aplicables
    def call
      return [] unless policy.apply_withholding?

      lines = []
      base  = taxable_base_cents

      concepts = WithholdingConcept.applicable_on(
        document.issue_date,
        taxpayer_type: document.taxpayer_type
      )

      concepts.each do |concept|
        next if base < concept.min_amount_cents

        amount = (base * concept.rate / 100.0).round
        next if amount.zero?

        lines << build_withholding_line(concept, base, amount)
      end

      lines += build_reteiva_lines if policy.apply_reteiva?

      lines
    end

    private

    # Base de retención = subtotal gravado ANTES de IVA (norma colombiana)
    def taxable_base_cents
      document.document_items
              .select { |i| i.taxed? || i.exempt? }
              .sum(&:net_cents)
    end

    def build_withholding_line(concept, base, amount)
      TaxLine.new(
        tax_document:        document,
        tax_type:            "retefuente",
        withholding_concept: concept,
        rate_snapshot:       concept.rate,
        base_cents:          base,
        amount_cents:        amount,
        direction:           "credit",
        calculated_at:       Time.current,
        calculation_detail:  {
          concept_code:       concept.code,
          concept_name:       concept.name,
          taxpayer_type:      document.taxpayer_type,
          base_cents:         base,
          min_amount_cents:   concept.min_amount_cents,
          rate:               concept.rate,
          formula:            "#{base} * #{concept.rate}% = #{amount}",
          uvt_2026:           UVT_2026,
          normativa:          "Art. 365-401 ET · Decreto 1625/2016",
          issue_date:         document.issue_date.to_s
        }.to_json
      )
    end

    # ReteIVA: Gran Contribuyente retiene 15% del IVA cobrado (Art. 437-1 ET)
    def build_reteiva_lines
      iva_base = document.document_items.select(&:taxed?).sum(&:tax_amount_cents)
      return [] if iva_base.zero?

      concept = WithholdingConcept.find_by(code: "RETEIVA-15", active: true)
      return [] unless concept

      amount = (iva_base * 0.15).round

      [TaxLine.new(
        tax_document:        document,
        tax_type:            "reteiva",
        withholding_concept: concept,
        rate_snapshot:       15.0,
        base_cents:          iva_base,
        amount_cents:        amount,
        direction:           "credit",
        calculated_at:       Time.current,
        calculation_detail:  {
          concept_name: "ReteIVA Gran Contribuyente 15%",
          base_cents:   iva_base,
          rate:         15.0,
          formula:      "#{iva_base} * 15% = #{amount}",
          normativa:    "Art. 437-1 ET"
        }.to_json
      )]
    end
  end
end
