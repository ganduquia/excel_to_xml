module Taxes
  class ReconciliationsController < ApplicationController
    before_action :load_period, only: %i[show import approve export destroy]

    def index
      @periods = ReconciliationPeriod.recent
    end

    def new
      @period = ReconciliationPeriod.new(
        fiscal_year:       Date.today.year,
        deferred_tax_rate: 0.35,
        status:            "draft"
      )
    end

    def create
      @period = ReconciliationPeriod.new(period_params)
      if @period.save
        redirect_to taxes_reconciliation_path(@period),
                    notice: "Período creado. Ahora carga el balance de comprobación desde Excel."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def show
      @items = @period.reconciliation_items.order(:account_code)
      @items = apply_filter(@items)

      @stats = build_stats
      @editing_item = load_editing_item
    end

    def import
      unless @period.editable?
        redirect_to taxes_reconciliation_path(@period),
                    alert: "El período #{@period.status} no permite importar."
        return
      end

      file = params[:file]
      if file.nil?
        redirect_to taxes_reconciliation_path(@period), alert: "Selecciona un archivo Excel."
        return
      end

      result = Taxes::BalanceImporter.new(file, @period).call

      if result.success
        meta = result.meta
        msg = "Importación exitosa: #{result.imported} cuentas cargadas."
        msg += " #{result.skipped} actualizadas (ya existían)." if result.skipped > 0
        msg += " Empresa: #{meta[:company_name]}."              if meta[:company_name].present?
        msg += " Período: #{meta[:period_range]}."              if meta[:period_range].present?
        redirect_to taxes_reconciliation_path(@period), notice: msg
      else
        redirect_to taxes_reconciliation_path(@period),
                    alert: "Error de importación: #{result.errors.first(3).join('. ')}"
      end
    end

    def approve
      unless @period.approvable?
        redirect_to taxes_reconciliation_path(@period),
                    alert: "Quedan #{@period.pending_count} cuentas sin revisar."
        return
      end
      @period.update!(status: "approved", approved_by: "admin", approved_at: Time.current)
      redirect_to taxes_reconciliation_path(@period), notice: "Conciliación aprobada correctamente."
    end

    def export
      items = @period.reconciliation_items.order(:account_code)
      xlsx  = Taxes::ReconciliationExporter.new(@period, items).call
      send_data xlsx,
                filename:    "conciliacion_fiscal_#{@period.fiscal_year}.xlsx",
                type:        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                disposition: "attachment"
    end

    def destroy
      if @period.approved?
        redirect_to taxes_reconciliations_path, alert: "No se puede eliminar un período aprobado."
        return
      end
      @period.destroy
      redirect_to taxes_reconciliations_path, notice: "Período eliminado."
    end

    private

    def load_period
      @period = ReconciliationPeriod.find(params[:id])
    end

    def period_params
      params.require(:reconciliation_period).permit(
        :name, :fiscal_year, :company_nit, :company_name,
        :start_date, :end_date, :deferred_tax_rate
      )
    end

    def apply_filter(scope)
      case params[:filter]
      when "pending"        then scope.where(review_status: "pending")
      when "with_effect"    then scope.where(has_fiscal_effect: true)
      when "without_effect" then scope.where(has_fiscal_effect: false)
      when "deferred"       then scope.where(applies_deferred_tax: true)
      else scope
      end
    end

    def build_stats
      all = @period.reconciliation_items
      {
        total:          all.count,
        pending:        all.where(review_status: "pending").count,
        reviewed:       all.where(review_status: "reviewed").count,
        with_effect:    all.where(has_fiscal_effect: true).count,
        without_effect: all.where(has_fiscal_effect: false).count,
        with_deferred:  all.where(applies_deferred_tax: true).count,
        total_adj:      all.sum(:fiscal_adjustment_cents),
        deferred_asset: all.where(deferred_tax_classification: "asset").sum(:deferred_tax_amount_cents),
        deferred_liab:  all.where(deferred_tax_classification: "liability").sum(:deferred_tax_amount_cents)
      }
    end

    def load_editing_item
      return nil unless params[:edit_item].present?
      @period.reconciliation_items.find_by(id: params[:edit_item])
    end
  end
end
