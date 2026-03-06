require "test_helper"

class Taxes::TaxLiquidatorTest < ActiveSupport::TestCase
  def setup
    @iva_rate = TaxRate.create!(
      name: "IVA 19%", tax_type: "iva", rate: 19.0,
      effective_from: Date.new(2026, 1, 1), active: true
    )

    @concept = WithholdingConcept.create!(
      code:             "0103-SERV-DEC",
      name:             "Servicios - Declarante",
      rate:             4.0,
      min_amount_cents: 21_282_400,
      taxpayer_type:    "declarante",
      base_type:        "bruto",
      effective_from:   Date.new(2026, 1, 1),
      active:           true
    )

    @document = TaxDocument.create!(
      document_type:        "invoice_purchase",
      number:               "FC-2026-LIQ-001",
      issue_date:           Date.new(2026, 3, 6),
      third_party_nit:      "900999888-7",
      third_party_name:     "Proveedor Tech S.A.S.",
      taxpayer_type:        "declarante",
      is_withholding_agent: true,
      currency:             "COP",
      withholding_concept:  @concept
    )

    DocumentItem.create!(
      tax_document:     @document,
      description:      "Desarrollo de software",
      quantity:         1,
      unit_price_cents: 10_000_000_00,
      tax_status:       "taxed",
      tax_rate:         @iva_rate
    )

    @document.reload
  end

  test "liquidación exitosa actualiza totales del documento" do
    result = Taxes::TaxLiquidator.call(@document)

    assert result[:success], result[:errors].inspect
    @document.reload

    # Subtotal = $10,000,000
    assert_equal 1_000_000_000, @document.subtotal_cents
    # IVA = $10,000,000 * 19% = $1,900,000
    assert_equal   190_000_000, @document.total_iva_cents
    # Retención = $10,000,000 * 4% = $400,000
    assert_equal    40_000_000, @document.total_withholding_cents
    # Total a pagar = $10,000,000 + $1,900,000 - $400,000 = $11,500,000
    assert_equal 1_150_000_000, @document.total_cents
  end

  test "result contiene summary con valores formateados en COP" do
    result = Taxes::TaxLiquidator.call(@document)

    assert result[:success]
    assert result[:summary].key?(:subtotal)
    assert result[:summary].key?(:iva)
    assert result[:summary].key?(:retenciones)
    assert result[:summary].key?(:total_a_pagar)
    assert_includes result[:summary][:subtotal], "COP"
  end

  test "liquidación falla si el documento no tiene ítems" do
    @document.document_items.destroy_all
    result = Taxes::TaxLiquidator.call(@document.reload)

    assert_not result[:success]
    assert result[:errors].any?
    assert_includes result[:errors].first, "ítem"
  end

  test "segunda liquidación reemplaza TaxLines anteriores" do
    Taxes::TaxLiquidator.call(@document)
    first_count = @document.tax_lines.count

    Taxes::TaxLiquidator.call(@document)
    second_count = @document.reload.tax_lines.count

    assert_equal first_count, second_count
  end

  test "documento cancelado no puede liquidarse" do
    @document.cancel!
    result = Taxes::TaxLiquidator.call(@document)

    assert_not result[:success]
    assert_includes result[:errors].first, "cancelado"
  end

  test "ítems mixtos (gravado + excluido + exento) liquidan correctamente" do
    @document.document_items.destroy_all

    DocumentItem.create!(
      tax_document: @document, description: "Servicio gravado",
      quantity: 1, unit_price_cents: 5_000_000_00,
      tax_status: "taxed", tax_rate: @iva_rate
    )
    DocumentItem.create!(
      tax_document: @document, description: "Medicamento excluido",
      quantity: 1, unit_price_cents: 2_000_000_00,
      tax_status: "excluded"
    )
    DocumentItem.create!(
      tax_document: @document, description: "Libro exento",
      quantity: 1, unit_price_cents: 1_000_000_00,
      tax_status: "exempt"
    )

    result = Taxes::TaxLiquidator.call(@document.reload)
    assert result[:success]

    @document.reload
    # IVA solo sobre ítem gravado: $5,000,000 * 19% = $950,000
    assert_equal 95_000_000, @document.total_iva_cents

    # Retención base = $5,000,000 (gravado) + $1,000,000 (exento) = $6,000,000
    # Pero $6,000,000 > 4 UVT ($212,824) → aplica
    assert @document.total_withholding_cents > 0
  end
end
