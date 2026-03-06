module Taxes
  class ReconciliationItemsController < ApplicationController
    before_action :load_item
    before_action :require_auxiliar_level

    def update
      unless @item.reconciliation_period.editable?
        redirect_to taxes_reconciliation_path(@item.reconciliation_period),
                    alert: "El período está aprobado y no puede modificarse."
        return
      end

      old_values = snapshot_fields

      # Construir hash plano (evita problemas con ActionController::Parameters)
      new_attrs = {
        has_fiscal_effect:       parse_fiscal_effect,
        fiscal_adjustment_cents: parse_adjustment_cents,
        adjustment_comment:      params.dig(:reconciliation_item, :adjustment_comment).to_s.strip.presence,
        exclusion_reason:        params.dig(:reconciliation_item, :exclusion_reason).to_s.strip.presence,
        review_status:           "reviewed",
        reviewed_by:             "admin",
        reviewed_at:             Time.current
      }

      if @item.update(new_attrs)
        save_audit_log(old_values)
        Taxes::ReconciliationPropagator.new(@item.reconciliation_period, @item).call
        redirect_to taxes_reconciliation_path(@item.reconciliation_period),
                    notice: "#{@item.account_code} — #{@item.account_name.truncate(40)} conciliada."
      else
        redirect_to taxes_reconciliation_path(@item.reconciliation_period,
                                              edit_item: @item.id),
                    alert: @item.errors.full_messages.join(". ")
      end
    end

    private

    def load_item
      @item = ReconciliationItem.find(params[:id])
    end

    def require_auxiliar_level
      unless @item.account_type.to_s.strip.downcase == "auxiliar"
        redirect_to taxes_reconciliation_path(@item.reconciliation_period),
                    alert: "Solo se pueden conciliar cuentas de nivel Auxiliar."
      end
    end

    def parse_fiscal_effect
      case params.dig(:reconciliation_item, :has_fiscal_effect).to_s
      when "true"  then true
      when "false" then false
      else nil
      end
    end

    def parse_adjustment_cents
      raw = params.dig(:reconciliation_item, :fiscal_adjustment_cents).to_s.gsub(/[^0-9.\-]/, "")
      return 0 if raw.blank?
      (raw.to_f * 100).round
    end

    def snapshot_fields
      {
        has_fiscal_effect:       @item.has_fiscal_effect,
        fiscal_adjustment_cents: @item.fiscal_adjustment_cents,
        adjustment_comment:      @item.adjustment_comment
      }
    end

    def save_audit_log(old_values)
      old_values.each do |field, old_val|
        new_val = @item.send(field)
        next if old_val == new_val
        @item.reconciliation_item_changes.create!(
          field_name: field.to_s,
          old_value:  old_val.to_s,
          new_value:  new_val.to_s,
          changed_by: "admin"
        )
      end
    end
  end
end
