module Taxes
  # Genera el soporte documental de la conciliación contable y fiscal en .xlsx
  # Hoja 1 — Carátula (resumen ejecutivo del período)
  # Hoja 2 — Conciliación Auxiliar (detalle completo cuenta por cuenta)
  # Hoja 3 — Ajustes Fiscales (solo cuentas con ajuste ≠ 0)
  # Hoja 4 — Impuesto Diferido (cuentas con ID calculado)
  # Hoja 5 — Resumen por Cuenta (agregado por primeros 4 dígitos)
  class ReconciliationExporter
    def initialize(period, items)
      @period = period
      @items  = items.to_a   # Auxiliar items
    end

    def call
      package = Axlsx::Package.new
      wb = package.workbook

      # ── Estilos ────────────────────────────────────────────────────────────
      @s = build_styles(wb)

      build_cover_sheet(wb)
      build_detail_sheet(wb)
      build_adjustments_sheet(wb)
      build_deferred_tax_sheet(wb)
      build_summary_sheet(wb)

      package.to_stream.read
    end

    private

    # ── Hoja 1: Carátula ────────────────────────────────────────────────────
    def build_cover_sheet(wb)
      wb.add_worksheet(name: "Carátula") do |ws|
        ws.add_row ["CONCILIACIÓN CONTABLE Y FISCAL"], style: @s[:title]
        ws.add_row ["Art. 772-1 E.T. — NIIF IAS 12"], style: @s[:subtitle]
        ws.add_row []

        info = [
          ["Período",         @period.name],
          ["Año fiscal",      @period.fiscal_year.to_s],
          ["Empresa",         @period.company_name.to_s],
          ["NIT",             @period.company_nit.to_s],
          ["Tasa ID",         "#{(@period.deferred_tax_rate * 100).round(1)}%"],
          ["Estado",          t_status(@period.status)],
          ["Aprobado por",    @period.approved_by.to_s],
          ["Fecha aprobación",@period.approved_at&.strftime("%d/%m/%Y %H:%M").to_s || "Pendiente"],
          ["Fecha exportación", Time.current.strftime("%d/%m/%Y %H:%M")]
        ]
        info.each { |row| ws.add_row row, style: [@s[:label], @s[:value]] }

        ws.add_row []
        ws.add_row ["RESUMEN ESTADÍSTICO"], style: @s[:header]
        ws.add_row []

        aux_items      = @items
        reviewed       = aux_items.select { |i| i.review_status == "reviewed" }
        with_effect    = aux_items.select { |i| i.has_fiscal_effect == true }
        without_effect = aux_items.select { |i| i.has_fiscal_effect == false }
        pending        = aux_items.select { |i| i.review_status == "pending" }
        with_adj       = aux_items.select { |i| i.fiscal_adjustment_cents.to_i != 0 }
        with_deferred  = aux_items.select { |i| i.applies_deferred_tax && i.deferred_tax_amount_cents.to_i > 0 }

        asset_total = aux_items.select { |i| i.deferred_tax_classification == "asset" }
                               .sum { |i| i.deferred_tax_amount_cents.to_i }
        liab_total  = aux_items.select { |i| i.deferred_tax_classification == "liability" }
                               .sum { |i| i.deferred_tax_amount_cents.to_i }

        stats = [
          ["Total cuentas auxiliares",          aux_items.count],
          ["Revisadas",                          reviewed.count],
          ["Pendientes de revisión",             pending.count],
          ["Con efecto fiscal (ajuste)",         with_effect.count],
          ["Sin efecto fiscal",                  without_effect.count],
          ["Con ajuste fiscal ≠ 0",              with_adj.count],
          ["Con impuesto diferido",              with_deferred.count],
          [],
          ["Total ajustes fiscales ($)",         pesos(sum_cents(aux_items, :fiscal_adjustment_cents))],
          ["Saldo fiscal total ($)",             pesos(sum_cents(aux_items.select { |i| i.fiscal_balance_cents }, :fiscal_balance_cents))],
          ["Diferencia temporaria total ($)",    pesos(sum_cents(aux_items, :temporary_difference_cents))],
          [],
          ["Activo por impuesto diferido ($)",   pesos(asset_total)],
          ["Pasivo por impuesto diferido ($)",   pesos(liab_total)],
          ["Impuesto diferido neto ($)",         pesos(asset_total - liab_total)]
        ]
        stats.each do |row|
          if row.empty?
            ws.add_row []
          else
            ws.add_row row, style: [
              @s[:label],
              row[1].is_a?(Numeric) ? @s[:currency] : @s[:value]
            ]
          end
        end

        ws.column_widths 40, 28
      end
    end

    # ── Hoja 2: Conciliación completa (Auxiliares) ──────────────────────────
    def build_detail_sheet(wb)
      wb.add_worksheet(name: "Conciliación Auxiliar") do |ws|
        ws.add_row([
          "Código", "Nombre", "Tipo Cta.",
          "Saldo Inicial", "Débito", "Crédito", "Saldo Contable",
          "Efecto Fiscal", "Ajuste Fiscal ($)", "Justificación del Ajuste",
          "Saldo Fiscal", "Dif. Temporaria",
          "Aplica ID", "Tasa ID", "Imp. Diferido ($)", "Clasif. ID",
          "Estado Revisión", "Revisado por", "Fecha Revisión"
        ], style: @s[:header])

        @items.each do |item|
          effect = case item.has_fiscal_effect
          when true  then "Sí"
          when false then "No"
          else "Sin revisar"
          end

          classif = case item.deferred_tax_classification
          when "asset"     then "Activo ID"
          when "liability" then "Pasivo ID"
          else "N/A"
          end

          row_style = if item.review_status == "pending"
            Array.new(19, @s[:pending_row])
          elsif item.fiscal_adjustment_cents.to_i != 0
            Array.new(19, @s[:adjusted_row])
          else
            Array.new(19, nil)
          end

          ws.add_row([
            item.account_code,
            item.account_name,
            item.account_type,
            pesos(item.opening_balance_cents),
            pesos(item.debit_cents),
            pesos(item.credit_cents),
            pesos(item.closing_balance_cents),
            effect,
            pesos(item.fiscal_adjustment_cents.to_i),
            item.adjustment_comment.to_s,
            item.fiscal_balance_cents ? pesos(item.fiscal_balance_cents) : "",
            pesos(item.temporary_difference_cents.to_i),
            item.applies_deferred_tax ? "Sí" : "No",
            item.deferred_tax_rate_snapshot.present? ? item.deferred_tax_rate_snapshot.to_f : "",
            item.applies_deferred_tax ? pesos(item.deferred_tax_amount_cents.to_i) : 0,
            classif,
            item.review_status == "reviewed" ? "Revisado" : "Pendiente",
            item.reviewed_by.to_s,
            item.reviewed_at&.strftime("%d/%m/%Y %H:%M").to_s
          ], style: row_style)
        end

        # Fila de totales
        reviewed_items = @items.select { |i| i.fiscal_balance_cents }
        ws.add_row([
          "TOTALES", "", "",
          pesos(sum_cents(@items, :opening_balance_cents)),
          pesos(sum_cents(@items, :debit_cents)),
          pesos(sum_cents(@items, :credit_cents)),
          pesos(sum_cents(@items, :closing_balance_cents)),
          "", pesos(sum_cents(@items, :fiscal_adjustment_cents)), "",
          pesos(sum_cents(reviewed_items, :fiscal_balance_cents)),
          pesos(sum_cents(@items, :temporary_difference_cents)),
          "", "",
          pesos(sum_cents(@items, :deferred_tax_amount_cents)),
          "", "", "", ""
        ], style: @s[:total_row])

        ws.column_widths 14, 42, 12, 14, 14, 14, 14, 11, 14, 50, 14, 14, 9, 8, 14, 12, 12, 16, 18
      end
    end

    # ── Hoja 3: Solo cuentas con ajuste fiscal ──────────────────────────────
    def build_adjustments_sheet(wb)
      adjusted = @items.select { |i| i.fiscal_adjustment_cents.to_i != 0 }

      wb.add_worksheet(name: "Ajustes Fiscales") do |ws|
        ws.add_row(["DETALLE DE AJUSTES FISCALES — #{@period.name}"], style: @s[:title])
        ws.add_row(["Art. 772-1 E.T. — Diferencias entre base contable y fiscal"], style: @s[:subtitle])
        ws.add_row []
        ws.add_row(["Total ajustes: #{adjusted.count} cuentas"], style: @s[:value])
        ws.add_row []

        ws.add_row([
          "Código", "Nombre",
          "Saldo Contable ($)", "Ajuste Fiscal ($)", "Saldo Fiscal ($)",
          "Dif. Temporaria ($)", "Justificación del Ajuste",
          "Revisado por", "Fecha"
        ], style: @s[:header])

        adjusted.each do |item|
          sign_style = item.fiscal_adjustment_cents > 0 ? @s[:positive] : @s[:negative]
          ws.add_row([
            item.account_code,
            item.account_name,
            pesos(item.closing_balance_cents),
            pesos(item.fiscal_adjustment_cents),
            pesos(item.fiscal_balance_cents.to_i),
            pesos(item.temporary_difference_cents.to_i),
            item.adjustment_comment.to_s,
            item.reviewed_by.to_s,
            item.reviewed_at&.strftime("%d/%m/%Y").to_s
          ], style: [nil, nil, @s[:currency], sign_style, @s[:currency], @s[:currency], nil, nil, nil])
        end

        unless adjusted.empty?
          ws.add_row([
            "TOTAL", "",
            pesos(sum_cents(adjusted, :closing_balance_cents)),
            pesos(sum_cents(adjusted, :fiscal_adjustment_cents)),
            pesos(sum_cents(adjusted, :fiscal_balance_cents)),
            pesos(sum_cents(adjusted, :temporary_difference_cents)),
            "", "", ""
          ], style: @s[:total_row])
        end

        ws.column_widths 14, 42, 16, 16, 16, 16, 55, 16, 12
      end
    end

    # ── Hoja 4: Impuesto diferido ────────────────────────────────────────────
    def build_deferred_tax_sheet(wb)
      with_id = @items.select { |i| i.applies_deferred_tax && i.deferred_tax_amount_cents.to_i > 0 }
      assets      = with_id.select { |i| i.deferred_tax_classification == "asset" }
      liabilities = with_id.select { |i| i.deferred_tax_classification == "liability" }

      wb.add_worksheet(name: "Impuesto Diferido") do |ws|
        ws.add_row(["IMPUESTO DIFERIDO — #{@period.name}"], style: @s[:title])
        ws.add_row(["NIC 12 / NIIF para PYMES — Diferencias temporarias en cuentas de Balance (Clase 1 y 2)"], style: @s[:subtitle])
        ws.add_row []

        ws.add_row(["RESUMEN"], style: @s[:header])
        asset_total = sum_cents(assets, :deferred_tax_amount_cents)
        liab_total  = sum_cents(liabilities, :deferred_tax_amount_cents)
        [
          ["Tasa de impuesto diferido aplicada",  "#{(@period.deferred_tax_rate * 100).round(1)}%"],
          ["Total cuentas con impuesto diferido", with_id.count.to_s],
          ["Activos por impuesto diferido",        assets.count.to_s],
          ["Pasivos por impuesto diferido",        liabilities.count.to_s],
          [],
          ["ACTIVO POR IMPUESTO DIFERIDO ($)",    pesos(asset_total)],
          ["PASIVO POR IMPUESTO DIFERIDO ($)",    pesos(liab_total)],
          ["IMPUESTO DIFERIDO NETO ($)",          pesos(asset_total - liab_total)]
        ].each do |row|
          if row.empty?
            ws.add_row []
          else
            ws.add_row row, style: [@s[:label], @s[:value]]
          end
        end

        ws.add_row []

        # Activos por ID
        if assets.any?
          ws.add_row(["ACTIVOS POR IMPUESTO DIFERIDO"], style: @s[:asset_header])
          ws.add_row(["Código", "Nombre", "Clase", "Saldo Contable ($)", "Ajuste ($)",
                      "Saldo Fiscal ($)", "Dif. Temporaria ($)", "Tasa", "Imp. Diferido ($)"],
                     style: @s[:header])
          assets.each do |item|
            ws.add_row([
              item.account_code, item.account_name, "Clase #{item.account_class}",
              pesos(item.closing_balance_cents), pesos(item.fiscal_adjustment_cents.to_i),
              pesos(item.fiscal_balance_cents.to_i), pesos(item.temporary_difference_cents.to_i),
              item.deferred_tax_rate_snapshot.to_f,
              pesos(item.deferred_tax_amount_cents.to_i)
            ], style: [nil, nil, nil, @s[:currency], @s[:currency], @s[:currency], @s[:currency], @s[:pct], @s[:currency]])
          end
          ws.add_row(["SUBTOTAL ACTIVO", "", "", "", "", "", "",
                      "", pesos(asset_total)], style: @s[:total_row])
          ws.add_row []
        end

        # Pasivos por ID
        if liabilities.any?
          ws.add_row(["PASIVOS POR IMPUESTO DIFERIDO"], style: @s[:liability_header])
          ws.add_row(["Código", "Nombre", "Clase", "Saldo Contable ($)", "Ajuste ($)",
                      "Saldo Fiscal ($)", "Dif. Temporaria ($)", "Tasa", "Imp. Diferido ($)"],
                     style: @s[:header])
          liabilities.each do |item|
            ws.add_row([
              item.account_code, item.account_name, "Clase #{item.account_class}",
              pesos(item.closing_balance_cents), pesos(item.fiscal_adjustment_cents.to_i),
              pesos(item.fiscal_balance_cents.to_i), pesos(item.temporary_difference_cents.to_i),
              item.deferred_tax_rate_snapshot.to_f,
              pesos(item.deferred_tax_amount_cents.to_i)
            ], style: [nil, nil, nil, @s[:currency], @s[:currency], @s[:currency], @s[:currency], @s[:pct], @s[:currency]])
          end
          ws.add_row(["SUBTOTAL PASIVO", "", "", "", "", "", "",
                      "", pesos(liab_total)], style: @s[:total_row])
        end

        ws.column_widths 14, 42, 10, 16, 14, 16, 16, 8, 16
      end
    end

    # ── Hoja 5: Resumen por Cuenta (primeros 4 dígitos) ─────────────────────
    def build_summary_sheet(wb)
      # Agrupar Auxiliares por los primeros 4 dígitos del código (nivel Cuenta PUC)
      by_cuenta = @items.group_by { |i| i.account_code.to_s[0..3] }
        .sort_by { |code, _| code }

      wb.add_worksheet(name: "Resumen por Cuenta") do |ws|
        ws.add_row(["RESUMEN AGREGADO POR CUENTA (4 DÍGITOS PUC)"], style: @s[:title])
        ws.add_row(["Calculado desde #{@items.count} cuentas Auxiliares"], style: @s[:subtitle])
        ws.add_row []

        ws.add_row([
          "Código Cta.", "Clase",
          "Saldo Contable ($)", "Ajuste Fiscal ($)", "Saldo Fiscal ($)",
          "Dif. Temporaria ($)", "Imp. Diferido ($)",
          "# Auxiliares", "# Revisados"
        ], style: @s[:header])

        by_cuenta.each do |cuenta_code, group|
          reviewed = group.select { |i| i.review_status == "reviewed" }
          ws.add_row([
            cuenta_code,
            "Clase #{cuenta_code[0]}",
            pesos(sum_cents(group, :closing_balance_cents)),
            pesos(sum_cents(group, :fiscal_adjustment_cents)),
            pesos(sum_cents(group.select { |i| i.fiscal_balance_cents }, :fiscal_balance_cents)),
            pesos(sum_cents(group, :temporary_difference_cents)),
            pesos(sum_cents(group, :deferred_tax_amount_cents)),
            group.count,
            reviewed.count
          ], style: [nil, nil, @s[:currency], @s[:currency], @s[:currency],
                     @s[:currency], @s[:currency], nil, nil])
        end

        ws.add_row([
          "TOTAL GENERAL", "",
          pesos(sum_cents(@items, :closing_balance_cents)),
          pesos(sum_cents(@items, :fiscal_adjustment_cents)),
          pesos(sum_cents(@items.select { |i| i.fiscal_balance_cents }, :fiscal_balance_cents)),
          pesos(sum_cents(@items, :temporary_difference_cents)),
          pesos(sum_cents(@items, :deferred_tax_amount_cents)),
          @items.count,
          @items.count { |i| i.review_status == "reviewed" }
        ], style: @s[:total_row])

        ws.column_widths 14, 10, 18, 18, 18, 18, 18, 12, 12
      end
    end

    # ── Estilos ────────────────────────────────────────────────────────────
    def build_styles(wb)
      s = wb.styles
      {
        title: s.add_style(
          bg_color: "312E81", fg_color: "FFFFFF",
          b: true, sz: 14, alignment: { horizontal: :left }
        ),
        subtitle: s.add_style(
          fg_color: "4338CA", sz: 10, i: true
        ),
        header: s.add_style(
          bg_color: "4F46E5", fg_color: "FFFFFF",
          b: true, sz: 10, alignment: { horizontal: :center, wrap_text: true }
        ),
        asset_header: s.add_style(
          bg_color: "065F46", fg_color: "FFFFFF", b: true, sz: 11
        ),
        liability_header: s.add_style(
          bg_color: "991B1B", fg_color: "FFFFFF", b: true, sz: 11
        ),
        label: s.add_style(b: true, sz: 10),
        value: s.add_style(sz: 10),
        currency: s.add_style(
          format_code: "#,##0", alignment: { horizontal: :right }, sz: 10
        ),
        pct: s.add_style(
          format_code: "0.00%", alignment: { horizontal: :right }, sz: 10
        ),
        positive: s.add_style(
          format_code: "#,##0", fg_color: "065F46",
          alignment: { horizontal: :right }, b: true, sz: 10
        ),
        negative: s.add_style(
          format_code: "#,##0", fg_color: "991B1B",
          alignment: { horizontal: :right }, b: true, sz: 10
        ),
        total_row: s.add_style(
          bg_color: "1E1B4B", fg_color: "FFFFFF",
          b: true, sz: 10
        ),
        pending_row: s.add_style(bg_color: "FEF9C3", sz: 10),
        adjusted_row: s.add_style(bg_color: "FFF7ED", sz: 10)
      }
    end

    # ── Helpers ────────────────────────────────────────────────────────────
    def pesos(cents)
      cents.to_i / 100.0
    end

    def sum_cents(collection, field)
      collection.sum { |i| i.send(field).to_i }
    end

    def t_status(status)
      { "draft" => "Borrador", "in_review" => "En revisión",
        "approved" => "Aprobado", "closed" => "Cerrado" }[status] || status
    end
  end
end
