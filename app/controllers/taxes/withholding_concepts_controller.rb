module Taxes
  class WithholdingConceptsController < ApplicationController
    before_action :set_concept, only: %i[show update destroy]

    # GET /taxes/withholding_concepts
    def index
      @concepts = WithholdingConcept.order(:code, :taxpayer_type)
      render json: @concepts.map { |c| concept_json(c) }
    end

    # GET /taxes/withholding_concepts/:id
    def show
      render json: concept_json(@concept)
    end

    # POST /taxes/withholding_concepts
    def create
      @concept = WithholdingConcept.new(concept_params)
      if @concept.save
        render json: concept_json(@concept), status: :created
      else
        render json: { errors: @concept.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PATCH /taxes/withholding_concepts/:id
    def update
      if @concept.update(concept_params)
        render json: concept_json(@concept)
      else
        render json: { errors: @concept.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /taxes/withholding_concepts/:id — solo desactiva, nunca borra
    def destroy
      @concept.update!(active: false)
      render json: { message: "Concepto desactivado", id: @concept.id }
    end

    # GET /taxes/withholding_concepts/applicable?taxpayer_type=declarante&date=2026-03-01
    def applicable
      date          = Date.parse(params[:date]) rescue Date.today
      taxpayer_type = params[:taxpayer_type] || "declarante"
      concepts      = WithholdingConcept.applicable_on(date, taxpayer_type: taxpayer_type)
      render json: concepts.map { |c| concept_json(c) }
    end

    private

    def set_concept
      @concept = WithholdingConcept.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Concepto no encontrado" }, status: :not_found
    end

    def concept_params
      params.require(:withholding_concept).permit(
        :code, :name, :rate, :min_amount_cents,
        :taxpayer_type, :base_type,
        :effective_from, :effective_to,
        :active, :notes
      )
    end

    def concept_json(concept)
      {
        id:               concept.id,
        code:             concept.code,
        name:             concept.name,
        rate:             concept.rate,
        rate_percent:     concept.rate_percent,
        min_amount_cents: concept.min_amount_cents,
        taxpayer_type:    concept.taxpayer_type,
        base_type:        concept.base_type,
        effective_from:   concept.effective_from,
        effective_to:     concept.effective_to,
        active:           concept.active,
        notes:            concept.notes
      }
    end
  end
end
