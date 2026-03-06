module Taxes
  class DocumentValidator
    attr_reader :document, :errors

    def initialize(document)
      @document = document
      @errors   = []
    end

    def valid?
      @errors = []
      run_validations
      @errors.empty?
    end

    private

    def run_validations
      validate_has_items
      validate_items_tax_status
      validate_taxed_items_have_rate
      validate_rates_active_on_issue_date
      validate_third_party_nit
      validate_credit_note_has_original
      validate_total_coherence
      validate_not_cancelled
    end

    def validate_has_items
      @errors << "El documento debe tener al menos un ítem" if document.document_items.empty?
    end

    def validate_items_tax_status
      document.document_items.each_with_index do |item, i|
        unless DocumentItem::TAX_STATUSES.include?(item.tax_status)
          @errors << "Ítem #{i + 1}: tax_status '#{item.tax_status}' no es válido"
        end
      end
    end

    def validate_taxed_items_have_rate
      document.document_items.select(&:taxed?).each_with_index do |item, i|
        @errors << "Ítem gravado #{i + 1} ('#{item.description}') no tiene tarifa IVA asignada" if item.tax_rate_id.blank?
      end
    end

    def validate_rates_active_on_issue_date
      return unless document.issue_date
      document.document_items.select(&:taxed?).each do |item|
        next unless item.tax_rate
        rate = item.tax_rate
        unless rate.active? &&
               rate.effective_from <= document.issue_date &&
               (rate.effective_to.nil? || rate.effective_to >= document.issue_date)
          @errors << "La tarifa '#{rate.name}' no está vigente para la fecha #{document.issue_date}"
        end
      end
    end

    def validate_third_party_nit
      @errors << "El NIT del tercero es requerido" if document.third_party_nit.blank?
    end

    def validate_credit_note_has_original
      return unless document.document_type.in?(%w[credit_note debit_note])
      @errors << "Nota crédito/débito requiere documento origen" if document.original_document_id.blank?
    end

    def validate_total_coherence
      return if document.document_items.empty?
      expected_subtotal    = document.document_items.sum(&:subtotal_cents)
      expected_iva         = document.document_items.sum(&:tax_amount_cents)
      return if expected_subtotal.zero?

      if document.subtotal_cents > 0 && (document.subtotal_cents - expected_subtotal).abs > 1
        @errors << "Subtotal del documento no coincide con la suma de ítems (diferencia: #{document.subtotal_cents - expected_subtotal} centavos)"
      end
    end

    def validate_not_cancelled
      @errors << "No se puede operar sobre un documento cancelado" if document.cancelled?
    end
  end
end
