module Taxes
  class IvaCalculator
    attr_reader :document, :policy

    def initialize(document)
      @document = document
      @policy   = TaxApplicabilityPolicy.new(document)
    end

    # Devuelve array de TaxLine (no persistidos) para todos los ítems del documento
    def call
      lines = []

      document.document_items.each do |item|
        if policy.apply_iva_to?(item)
          lines << build_iva_line(item)
        elsif policy.declare_exempt?(item)
          lines << build_exempt_line(item)
        end
        # excluded: no genera ninguna TaxLine
      end

      lines
    end

    private

    def build_iva_line(item)
      rate      = item.tax_rate
      base      = item.net_cents
      amount    = (base * rate.rate / 100.0).round

      TaxLine.new(
        tax_document:       document,
        tax_type:           "iva",
        withholding_concept: nil,
        rate_snapshot:      rate.rate,
        base_cents:         base,
        amount_cents:       amount,
        direction:          "charge",
        calculated_at:      Time.current,
        calculation_detail: {
          item_description: item.description,
          quantity:         item.quantity,
          unit_price_cents: item.unit_price_cents,
          discount_cents:   item.discount_cents,
          base_cents:       base,
          rate:             rate.rate,
          rate_name:        rate.name,
          formula:          "#{base} * #{rate.rate}% = #{amount}",
          issue_date:       document.issue_date.to_s,
          uvt_2026:         5_320_600  # UVT 2026 = $53,206 COP (Res. DIAN 2025)
        }.to_json
      )
    end

    def build_exempt_line(item)
      base = item.net_cents

      TaxLine.new(
        tax_document:        document,
        tax_type:            "iva",
        withholding_concept: nil,
        rate_snapshot:       0.0,
        base_cents:          base,
        amount_cents:        0,
        direction:           "charge",
        calculated_at:       Time.current,
        calculation_detail:  {
          item_description: item.description,
          tax_status:       "exempt",
          base_cents:       base,
          rate:             0,
          formula:          "Exento tarifa 0% - Art. 477 ET",
          note:             "Declarativo. No genera cobro de IVA."
        }.to_json
      )
    end
  end
end
