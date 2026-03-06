module Taxes
  class ReconciliationItemsController < ApplicationController
    before_action :load_item

    def update
      old_values = snapshot_fields

      # Convertir has_fiscal_effect de string a tipo correcto
      effect_raw = params.dig(:reconciliation_item, :has_fiscal_effect).to_s
      parsed_params = item_params
      parsed_params[:has_fiscal_effect] = parse_fiscal_effect(effect_raw)

      # Convertir ajuste de pesos a centavos
      if parsed_params[:fiscal_adjustment_cents].present?
        parsed_params[:fiscal_adjustment_cents] =
          (parsed_params[:fiscal_adjustment_cents].to_s.gsub(/[^0-9.\-]/, "").to_f * 100).round
      end

      parsed_params[:review_status] = "reviewed"
      parsed_params[:reviewed_by]   = "admin"
      parsed_params[:reviewed_at]   = Time.current

      if @item.update(parsed_params)
        save_audit_log(old_values)
        redirect_to taxes_reconciliation_path(@item.reconciliation_period),
                    notice: "Cuenta #{@item.account_code} — #{@item.account_name} actualizada."
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

    def item_params
      params.require(:reconciliation_item).permit(
        :has_fiscal_effect, :fiscal_adjustment_cents,
        :adjustment_comment, :exclusion_reason
      )
    end

    def parse_fiscal_effect(val)
      case val
      when "true"  then true
      when "false" then false
      else nil
      end
    end

    def snapshot_fields
      {
        has_fiscal_effect:      @item.has_fiscal_effect,
        fiscal_adjustment_cents: @item.fiscal_adjustment_cents,
        adjustment_comment:     @item.adjustment_comment
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
