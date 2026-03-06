require "caxlsx"

module Taxes
  class DocumentsExcelExporter
    HEADERS = [
      "Número", "Tipo", "Fecha", "NIT Tercero", "Nombre Tercero",
      "Tipo Contribuyente", "Agente Retención", "Concepto Retención",
      "Subtotal (COP)", "IVA (COP)", "Retenciones (COP)", "Total a Pagar (COP)",
      "Estado", "Moneda", "Notas"
    ].freeze

    DOCUMENT_TYPES = {
      "invoice_sale"     => "Factura venta",
      "invoice_purchase" => "Factura compra",
      "debit_note"       => "Nota débito",
      "credit_note"      => "Nota crédito"
    }.freeze

    STATUSES = {
      "draft"     => "Borrador",
      "active"    => "Activo",
      "cancelled" => "Cancelado"
    }.freeze

    def initialize(documents)
      @documents = documents
    end

    def generate
      package = Axlsx::Package.new
      wb = package.workbook

      # ── Estilos ─────────────────────────────────────────────────────────
      styles = wb.styles
      header_style = styles.add_style(
        bg_color: "4A1A7A", fg_color: "FFFFFF",
        b: true, sz: 11, alignment: { horizontal: :center },
        border: { style: :thin, color: "CCCCCC" }
      )
      currency_style = styles.add_style(
        format_code: '"$"#,##0',
        alignment:   { horizontal: :right },
        border:      { style: :thin, color: "EEEEEE" }
      )
      date_style = styles.add_style(
        format_code: "DD/MM/YYYY",
        alignment:   { horizontal: :center },
        border:      { style: :thin, color: "EEEEEE" }
      )
      text_style = styles.add_style(
        border: { style: :thin, color: "EEEEEE" }
      )
      badge_active = styles.add_style(
        fg_color: "166534", bg_color: "DCFCE7",
        border: { style: :thin, color: "EEEEEE" }
      )
      badge_draft = styles.add_style(
        fg_color: "854D0E", bg_color: "FEF9C3",
        border: { style: :thin, color: "EEEEEE" }
      )
      badge_cancelled = styles.add_style(
        fg_color: "6B7280", bg_color: "F3F4F6",
        border: { style: :thin, color: "EEEEEE" }
      )

      # ── Hoja de documentos ───────────────────────────────────────────────
      wb.add_worksheet(name: "Documentos") do |sheet|

        # Título
        sheet.add_row(
          ["Reporte de Documentos Contables — Colombia 2026"],
          style: styles.add_style(b: true, sz: 14, fg_color: "4A1A7A"),
          height: 24
        )
        sheet.add_row(
          ["Generado: #{Time.current.strftime('%d/%m/%Y %H:%M')} · Total: #{@documents.count} documentos"]
        )
        sheet.add_row([])

        # Encabezados
        sheet.add_row(HEADERS, style: header_style, height: 18)

        # Datos
        @documents.each do |doc|
          status_style = case doc.status
                         when "active"    then badge_active
                         when "draft"     then badge_draft
                         when "cancelled" then badge_cancelled
                         else text_style
                         end

          sheet.add_row(
            [
              doc.number,
              DOCUMENT_TYPES[doc.document_type] || doc.document_type,
              doc.issue_date,
              doc.third_party_nit,
              doc.third_party_name,
              doc.taxpayer_type,
              doc.is_withholding_agent? ? "Sí" : "No",
              doc.withholding_concept&.name || "—",
              doc.subtotal_cents          / 100.0,
              doc.total_iva_cents         / 100.0,
              doc.total_withholding_cents / 100.0,
              doc.total_cents             / 100.0,
              STATUSES[doc.status] || doc.status,
              doc.currency,
              doc.notes.to_s
            ],
            style: [
              text_style, text_style, date_style,
              text_style, text_style, text_style, text_style, text_style,
              currency_style, currency_style, currency_style, currency_style,
              status_style, text_style, text_style
            ]
          )
        end

        # Fila de totales
        last_row = @documents.count + 5
        sheet.add_row([])
        sheet.add_row(
          [
            "TOTALES", "", "", "", "", "", "", "",
            @documents.sum(:subtotal_cents)          / 100.0,
            @documents.sum(:total_iva_cents)         / 100.0,
            @documents.sum(:total_withholding_cents) / 100.0,
            @documents.sum(:total_cents)             / 100.0,
            "", "", ""
          ],
          style: styles.add_style(b: true, bg_color: "EDE9FE",
                                   border: { style: :thin, color: "CCCCCC" })
        )

        # Anchos de columna
        sheet.column_widths 18, 18, 13, 18, 28, 20, 16, 32,
                            16, 16, 18, 18, 12, 8, 30
      end

      # ── Hoja de resumen ──────────────────────────────────────────────────
      wb.add_worksheet(name: "Resumen") do |sheet|
        title_style  = styles.add_style(b: true, sz: 13, fg_color: "4A1A7A")
        label_style  = styles.add_style(b: true, bg_color: "F3F0FF")
        value_style  = styles.add_style(format_code: '"$"#,##0', alignment: { horizontal: :right })
        count_style  = styles.add_style(alignment: { horizontal: :center })

        sheet.add_row(["Resumen Ejecutivo"], style: title_style, height: 22)
        sheet.add_row(["Generado: #{Time.current.strftime('%d/%m/%Y %H:%M')}"])
        sheet.add_row([])

        sheet.add_row(["Métrica", "Cantidad", "Valor Total (COP)"],
                      style: header_style, height: 16)

        {
          "Total documentos"         => :all,
          "Facturas de venta"        => :invoice_sale,
          "Facturas de compra"       => :invoice_purchase,
          "Notas débito"             => :debit_note,
          "Notas crédito"            => :credit_note,
          "--- Estado ---"           => :separator,
          "Borradores"               => :draft,
          "Activos / Liquidados"     => :active,
          "Cancelados"               => :cancelled
        }.each do |label, key|
          if key == :separator
            sheet.add_row([label], style: styles.add_style(b: true, fg_color: "6B7280", i: true))
            next
          end

          subset = case key
                   when :all             then @documents
                   when :invoice_sale    then @documents.where(document_type: "invoice_sale")
                   when :invoice_purchase then @documents.where(document_type: "invoice_purchase")
                   when :debit_note      then @documents.where(document_type: "debit_note")
                   when :credit_note     then @documents.where(document_type: "credit_note")
                   when :draft           then @documents.where(status: "draft")
                   when :active          then @documents.where(status: "active")
                   when :cancelled       then @documents.where(status: "cancelled")
                   end

          sheet.add_row(
            [label, subset.count, subset.sum(:total_cents) / 100.0],
            style: [label_style, count_style, value_style]
          )
        end

        sheet.column_widths 30, 12, 22
      end

      package.to_stream.read
    end
  end
end
