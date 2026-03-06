module Taxes
  class DocumentsController < ApplicationController
    before_action :set_document, only: %i[show destroy liquidate cancel]

    def index
      @filter    = DocumentFilter.new(params)
      @documents = @filter
                     .apply(TaxDocument.all)
                     .order(issue_date: :desc, id: :desc)
                     .page(params[:page]).per(10)
    end

    def show
      @tax_lines = @document.tax_lines.includes(:withholding_concept)
    end

    def new
      @document = TaxDocument.new(issue_date: Date.today, currency: "COP")
      @document.document_items.build
      load_form_options
    end

    def create
      @document = TaxDocument.new(document_params)
      if @document.save
        redirect_to taxes_document_path(@document), notice: "Documento creado correctamente."
      else
        load_form_options
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      if @document.cancelled?
        redirect_to taxes_documents_path, alert: "El documento ya está cancelado."
      else
        @document.cancel!
        redirect_to taxes_documents_path, notice: "Documento cancelado."
      end
    end

    def liquidate
      result = Taxes::TaxLiquidator.call(@document)
      if result[:success]
        redirect_to taxes_document_path(@document),
                    notice: "Liquidación exitosa — #{result[:summary][:total_a_pagar]}"
      else
        redirect_to taxes_document_path(@document),
                    alert: result[:errors].join(", ")
      end
    end

    def cancel
      if @document.cancelled?
        redirect_to taxes_document_path(@document), alert: "Ya está cancelado."
      else
        @document.cancel!
        redirect_to taxes_documents_path, notice: "Documento cancelado correctamente."
      end
    end

    private

    def set_document
      @document = TaxDocument.includes(:document_items, tax_lines: :withholding_concept).find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to taxes_documents_path, alert: "Documento no encontrado."
    end

    def load_form_options
      @tax_rates          = TaxRate.where(tax_type: "iva", active: true).order(:rate)
      @withholding_concepts = WithholdingConcept.where(active: true).order(:code)
    end

    def document_params
      params.require(:tax_document).permit(
        :document_type, :number, :issue_date,
        :third_party_nit, :third_party_name,
        :taxpayer_type, :is_withholding_agent,
        :third_party_autoretainer, :currency, :notes,
        :withholding_concept_id,
        document_items_attributes: %i[
          id description quantity unit_price_cents
          discount_cents tax_status tax_rate_id _destroy
        ]
      )
    end
  end
end
