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
end
