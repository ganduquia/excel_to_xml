module Taxes
  class ReconciliationExporter
    def initialize(period, items)
      @period = period
      @items  = items
    end

    def call
      package = Axlsx::Package.new
      wb = package.workbook

      header_style = wb.styles.add_style(
        bg_color: "4F46E5", fg_color: "FFFFFF",
        b: true, sz: 10, alignment: { horizontal: :center }
      )
      currency_style = wb.styles.add_style(
        format_code: "#,##0", alignment: { horizontal: :right }
      )
      pct_style = wb.styles.add_style(
        format_code: "0.00%", alignment: { horizontal: :right }
      )
      diff_style_pos = wb.styles.add_style(
        format_code: "#,##0", alignment: { horizontal: :right },
        bg_color: "FEF9C3"
      )
      diff_style_neg = wb.styles.add_style(
        format_code: "#,##0", alignment: { horizontal: :right },
        bg_color: "FEE2E2"
      )
      asset_style = wb.styles.add_style(bg_color: "D1FAE5", sz: 10)
      liability_style = wb.styles.add_style(bg_color: "FEE2E2", sz: 10)

      # ── Hoja 1: Conciliación completa ─────────────────────────────────────
      wb.add_worksheet(name: "Conciliación Fiscal") do |ws|
        ws.add_row(
          ["Tipo", "Cuenta", "Nombre", "Saldo Inicial", "Débito", "Crédito",
           "Saldo Contable", "Efecto Fiscal", "Ajuste Fiscal",
           "Comentario Ajuste", "Saldo Fiscal", "Dif. Temporaria",
           "Tasa ID", "Imp. Diferido", "Clasificación ID"],
          style: header_style
        )

        @items.each do |item|
          effect = if item.has_fiscal_effect.nil?
            "Sin revisar"
          elsif item.has_fiscal_effect
            "Sí"
          else
            "No"
          end

          classif = case item.deferred_tax_classification
          when "asset" then "Activo ID"
          when "liability" then "Pasivo ID"
          else "N/A"
          end

          row_style = case item.deferred_tax_classification
          when "asset" then [nil, nil, nil, nil, nil, nil, nil, nil,
                             currency_style, nil, currency_style,
                             diff_style_pos, pct_style, currency_style, nil]
          when "liability" then [nil, nil, nil, nil, nil, nil, nil, nil,
                                 currency_style, nil, currency_style,
                                 diff_style_neg, pct_style, currency_style, nil]
          else Array.new(15, nil)
          end

          ws.add_row([
            item.account_type,
            item.account_code,
            item.account_name,
            pesos(item.opening_balance_cents),
            pesos(item.debit_cents),
            pesos(item.credit_cents),
            pesos(item.closing_balance_cents),
            effect,
            pesos(item.fiscal_adjustment_cents),
            item.adjustment_comment.to_s,
            item.fiscal_balance_cents ? pesos(item.fiscal_balance_cents) : "",
            item.temporary_difference_cents != 0 ? pesos(item.temporary_difference_cents) : 0,
            item.deferred_tax_rate_snapshot || "",
            item.applies_deferred_tax ? pesos(item.deferred_tax_amount_cents) : 0,
            classif
          ], style: row_style)
        end

        # Fila de totales
        n = @items.count + 1
        ws.add_row([
          "TOTALES", "", "",
          @items.sum(:opening_balance_cents) / 100.0,
          @items.sum(:debit_cents) / 100.0,
          @items.sum(:credit_cents) / 100.0,
          @items.sum(:closing_balance_cents) / 100.0,
          "", @items.sum(:fiscal_adjustment_cents) / 100.0,
          "", @items.where.not(fiscal_balance_cents: nil).sum(:fiscal_balance_cents) / 100.0,
          @items.sum(:temporary_difference_cents) / 100.0,
          "",
          @items.sum(:deferred_tax_amount_cents) / 100.0,
          ""
        ], style: wb.styles.add_style(b: true))

        ws.column_widths 15, 14, 40, 14, 14, 14, 14, 12, 14, 35, 14, 14, 8, 14, 14
      end

      # ── Hoja 2: Resumen de impuesto diferido ─────────────────────────────
      wb.add_worksheet(name: "Impuesto Diferido") do |ws|
        ws.add_row(["Resumen Impuesto Diferido — #{@period.name}"], style: header_style)
        ws.add_row([])
        ws.add_row(["Concepto", "Valor ($)"], style: header_style)

        asset_total     = @period.total_deferred_tax_asset_cents / 100.0
        liability_total = @period.total_deferred_tax_liability_cents / 100.0
        net             = asset_total - liability_total

        ws.add_row(["Activo por impuesto diferido",   asset_total],     style: [nil, currency_style])
        ws.add_row(["Pasivo por impuesto diferido",   liability_total], style: [nil, currency_style])
        ws.add_row(["Impuesto diferido neto (Activo)", net],            style: [nil, currency_style])
        ws.add_row([])
        ws.add_row(["Tasa utilizada", @period.deferred_tax_rate], style: [nil, pct_style])
        ws.add_row(["Período fiscal", @period.fiscal_year])
        ws.add_row(["Estado", @period.status])
        ws.add_row(["Aprobado por", @period.approved_by.to_s])
        ws.add_row(["Fecha aprobación", @period.approved_at&.strftime("%d/%m/%Y %H:%M").to_s])
        ws.column_widths 40, 20
      end

      # ── Hoja 3: Detalle de ajustes ────────────────────────────────────────
      wb.add_worksheet(name: "Ajustes Fiscales") do |ws|
        ws.add_row(["Cuenta", "Nombre", "Ajuste ($)", "Comentario", "Revisado por", "Fecha revisión"],
                   style: header_style)

        @items.where(has_fiscal_effect: true).where.not(fiscal_adjustment_cents: 0).each do |item|
          ws.add_row([
            item.account_code,
            item.account_name,
            pesos(item.fiscal_adjustment_cents),
            item.adjustment_comment.to_s,
            item.reviewed_by.to_s,
            item.reviewed_at&.strftime("%d/%m/%Y %H:%M").to_s
          ], style: [nil, nil, currency_style, nil, nil, nil])
        end

        ws.column_widths 14, 40, 14, 50, 20, 18
      end

      package.to_stream.read
    end

    private

    def pesos(cents)
      cents.to_i / 100.0
    end
  end
end
