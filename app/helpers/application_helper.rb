module ApplicationHelper
  # Formatea centavos a pesos COP: 190_000_00 → "$1,900,000"
  def format_cop(cents)
    return "$0" if cents.nil? || cents.zero?
    pesos = cents / 100.0
    "$#{number_with_delimiter(pesos.to_i)}"
  end

  def status_badge(status)
    classes = { "draft" => "bg-warning text-dark", "active" => "bg-success", "cancelled" => "bg-secondary" }
    labels  = { "draft" => "Borrador", "active" => "Activo", "cancelled" => "Cancelado" }
    content_tag(:span, labels[status] || status, class: "badge #{classes[status] || 'bg-secondary'}")
  end

  def tax_status_badge(status)
    classes = { "taxed" => "bg-danger", "excluded" => "bg-secondary", "exempt" => "bg-info text-dark" }
    labels  = { "taxed" => "Gravado", "excluded" => "Excluido", "exempt" => "Exento" }
    content_tag(:span, labels[status] || status, class: "badge #{classes[status] || 'bg-secondary'}")
  end

  def t_document_type(type)
    { "invoice_sale" => "Factura venta", "invoice_purchase" => "Factura compra",
      "debit_note" => "Nota débito", "credit_note" => "Nota crédito" }[type] || type
  end

  def t_taxpayer_type(type)
    { "declarante" => "Declarante", "no_declarante" => "No declarante",
      "gran_contribuyente" => "Gran contribuyente", "autorretenedor" => "Autorretenedor",
      "regimen_simple" => "Régimen simple", "no_responsable_iva" => "No responsable IVA" }[type] || type
  end

  # ── Helpers para Conciliación Contable y Fiscal ──────────────────────────

  def format_cop_signed(cents)
    return "$0" if cents.nil? || cents.zero?
    pesos = cents.to_i / 100.0
    sign  = pesos >= 0 ? "+" : ""
    "#{sign}$#{number_with_delimiter(pesos.to_i)}"
  end

  def t_recon_status(status)
    { "draft" => "Borrador", "in_review" => "En revisión",
      "approved" => "Aprobado", "closed" => "Cerrado" }[status] || status
  end

  def status_badge_class(status)
    { "draft" => "bg-secondary", "in_review" => "bg-warning text-dark",
      "approved" => "bg-success", "closed" => "bg-dark" }[status] || "bg-secondary"
  end

  def fiscal_effect_badge(val)
    if val.nil?
      content_tag(:span, "Sin revisar", class: "badge bg-secondary")
    elsif val
      content_tag(:span, "Sí", class: "badge bg-warning text-dark")
    else
      content_tag(:span, "No", class: "badge bg-success")
    end
  end

  def deferred_tax_badge(classification)
    case classification
    when "asset"
      content_tag(:span, "Activo ID", class: "badge bg-success")
    when "liability"
      content_tag(:span, "Pasivo ID", class: "badge bg-danger")
    else
      content_tag(:span, "N/A", class: "badge bg-light text-muted border")
    end
  end

  def row_class(item)
    return "table-warning" if item.review_status == "pending"
    return "table-success"  if item.has_fiscal_effect == false
    return "table-info"     if item.has_fiscal_effect == true && item.fiscal_adjustment_cents.to_i != 0
    ""
  end
end
