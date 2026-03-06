module Taxes
  class TaxRatesController < ApplicationController
    def index
      @rates = TaxRate.order(tax_type: :asc, effective_from: :desc)
    end

    def new
      @rate = TaxRate.new(effective_from: Date.today, active: true)
    end

    def create
      @rate = TaxRate.new(tax_rate_params)
      if @rate.save
        redirect_to taxes_tax_rates_path, notice: "Tarifa creada correctamente."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      TaxRate.find(params[:id]).update!(active: false)
      redirect_to taxes_tax_rates_path, notice: "Tarifa desactivada."
    rescue ActiveRecord::RecordNotFound
      redirect_to taxes_tax_rates_path, alert: "Tarifa no encontrada."
    end

    private

    def tax_rate_params
      params.require(:tax_rate).permit(:name, :tax_type, :rate, :effective_from, :effective_to, :active, :notes)
    end
  end
end
