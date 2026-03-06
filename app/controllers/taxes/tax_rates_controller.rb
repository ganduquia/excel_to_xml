module Taxes
  class TaxRatesController < ApplicationController
    before_action :set_tax_rate, only: %i[show update destroy]

    # GET /taxes/tax_rates
    def index
      @rates = TaxRate.order(tax_type: :asc, effective_from: :desc)
      render json: @rates.map { |r| rate_json(r) }
    end

    # GET /taxes/tax_rates/:id
    def show
      render json: rate_json(@tax_rate)
    end

    # POST /taxes/tax_rates
    def create
      @tax_rate = TaxRate.new(tax_rate_params)
      if @tax_rate.save
        render json: rate_json(@tax_rate), status: :created
      else
        render json: { errors: @tax_rate.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PATCH /taxes/tax_rates/:id
    def update
      if @tax_rate.update(tax_rate_params)
        render json: rate_json(@tax_rate)
      else
        render json: { errors: @tax_rate.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /taxes/tax_rates/:id
    def destroy
      @tax_rate.update!(active: false)
      render json: { message: "Tarifa desactivada", id: @tax_rate.id }
    end

    # GET /taxes/tax_rates/active?tax_type=iva&date=2026-03-01
    def active
      date     = Date.parse(params[:date]) rescue Date.today
      tax_type = params[:tax_type] || "iva"
      rate     = TaxRate.active_on(date, tax_type: tax_type)
      if rate
        render json: rate_json(rate)
      else
        render json: { error: "No hay tarifa activa para #{tax_type} en #{date}" }, status: :not_found
      end
    end

    private

    def set_tax_rate
      @tax_rate = TaxRate.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Tarifa no encontrada" }, status: :not_found
    end

    def tax_rate_params
      params.require(:tax_rate).permit(:name, :tax_type, :rate, :effective_from, :effective_to, :active, :notes)
    end

    def rate_json(rate)
      {
        id:             rate.id,
        name:           rate.name,
        tax_type:       rate.tax_type,
        rate:           rate.rate,
        rate_percent:   rate.rate_percent,
        effective_from: rate.effective_from,
        effective_to:   rate.effective_to,
        active:         rate.active,
        notes:          rate.notes
      }
    end
  end
end
