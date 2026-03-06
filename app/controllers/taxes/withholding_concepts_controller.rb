module Taxes
  class WithholdingConceptsController < ApplicationController
    def index
      @concepts = WithholdingConcept.order(:code, :taxpayer_type)
    end

    def new
      @concept = WithholdingConcept.new(effective_from: Date.today, active: true, base_type: "bruto")
    end

    def create
      @concept = WithholdingConcept.new(concept_params)
      if @concept.save
        redirect_to taxes_withholding_concepts_path, notice: "Concepto creado correctamente."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def toggle
      concept = WithholdingConcept.find(params[:id])
      concept.update!(active: !concept.active)
      msg = concept.active? ? "Concepto activado." : "Concepto desactivado."
      redirect_to taxes_withholding_concepts_path, notice: msg
    rescue ActiveRecord::RecordNotFound
      redirect_to taxes_withholding_concepts_path, alert: "Concepto no encontrado."
    end

    private

    def concept_params
      params.require(:withholding_concept).permit(
        :code, :name, :rate, :min_amount_cents,
        :taxpayer_type, :base_type,
        :effective_from, :effective_to, :active, :notes
      )
    end
  end
end
