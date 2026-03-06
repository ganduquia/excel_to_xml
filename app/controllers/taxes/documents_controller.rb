module Taxes
  class DocumentsController < ApplicationController
    before_action :set_document, only: %i[show update destroy liquidate cancel]

    # GET /taxes/documents
    def index
      @documents = TaxDocument.all.order(issue_date: :desc)
      render json: documents_json(@documents)
    end

    # GET /taxes/documents/:id
    def show
      render json: document_json(@document)
    end

    # POST /taxes/documents
    def create
      @document = TaxDocument.new(document_params)
      if @document.save
        render json: document_json(@document), status: :created
      else
        render json: { errors: @document.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PATCH /taxes/documents/:id
    def update
      if @document.cancelled?
        return render json: { error: "No se puede modificar un documento cancelado" }, status: :unprocessable_entity
      end
      if @document.update(document_params)
        render json: document_json(@document)
      else
        render json: { errors: @document.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /taxes/documents/:id
    def destroy
      if @document.cancelled?
        render json: { error: "Ya está cancelado" }, status: :unprocessable_entity
      else
        @document.cancel!
        render json: { message: "Documento cancelado correctamente", id: @document.id }
      end
    end

    # POST /taxes/documents/:id/liquidate
    # Calcula y persiste todos los impuestos del documento
    def liquidate
      result = Taxes::TaxLiquidator.call(@document)
      if result[:success]
        render json: {
          message:   "Liquidación exitosa",
          document:  document_json(@document),
          resultado: result[:summary],
          iva_lines: result[:iva_lines].map { |l| tax_line_json(l) },
          withholding_lines: result[:withholding_lines].map { |l| tax_line_json(l) }
        }
      else
        render json: { errors: result[:errors] }, status: :unprocessable_entity
      end
    end

    # POST /taxes/documents/:id/cancel
    def cancel
      if @document.cancelled?
        render json: { error: "El documento ya está cancelado" }, status: :unprocessable_entity
      else
        @document.cancel!
        render json: { message: "Documento cancelado", id: @document.id }
      end
    end

    private

    def set_document
      @document = TaxDocument.includes(:document_items, :tax_lines).find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Documento no encontrado" }, status: :not_found
    end

    def document_params
      params.require(:tax_document).permit(
        :document_type, :number, :issue_date,
        :third_party_nit, :third_party_name,
        :taxpayer_type, :is_withholding_agent,
        :third_party_autoretainer, :currency,
        :original_document_id, :notes,
        document_items_attributes: %i[
          id description quantity unit_price_cents
          discount_cents tax_status tax_rate_id _destroy
        ]
      )
    end

    def documents_json(documents)
      documents.map { |d| document_json(d) }
    end

    def document_json(doc)
      {
        id:                      doc.id,
        document_type:           doc.document_type,
        number:                  doc.number,
        issue_date:              doc.issue_date,
        third_party_nit:         doc.third_party_nit,
        third_party_name:        doc.third_party_name,
        taxpayer_type:           doc.taxpayer_type,
        is_withholding_agent:    doc.is_withholding_agent,
        third_party_autoretainer: doc.third_party_autoretainer,
        status:                  doc.status,
        subtotal_cents:          doc.subtotal_cents,
        total_iva_cents:         doc.total_iva_cents,
        total_withholding_cents: doc.total_withholding_cents,
        total_cents:             doc.total_cents,
        currency:                doc.currency,
        items_count:             doc.document_items.size,
        tax_lines_count:         doc.tax_lines.size
      }
    end

    def tax_line_json(line)
      {
        tax_type:      line.tax_type,
        direction:     line.direction,
        rate_snapshot: line.rate_snapshot,
        base_cents:    line.base_cents,
        amount_cents:  line.amount_cents,
        detail:        line.calculation_detail_parsed
      }
    end
  end
end
