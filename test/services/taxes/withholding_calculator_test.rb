require "test_helper"

class Taxes::WithholdingCalculatorTest < ActiveSupport::TestCase
  def setup
    @iva_rate = TaxRate.create!(
      name: "IVA 19%", tax_type: "iva", rate: 19.0,
      effective_from: Date.new(2026, 1, 1), active: true
    )

    @concept_servicios = WithholdingConcept.create!(
      code:             "0103-SERV-DEC",
      name:             "Servicios generales - Declarante",
      rate:             4.0,
      min_amount_cents: 21_282_400,  # 4 UVT * 53,206 * 100
      taxpayer_type:    "declarante",
      base_type:        "bruto",
      effective_from:   Date.new(2026, 1, 1),
      active:           true
    )

    @document = TaxDocument.create!(
      document_type:        "invoice_purchase",
      number:               "FC-2026-TEST",
      issue_date:           Date.new(2026, 3, 6),
      third_party_nit:      "900123456-1",
      third_party_name:     "Proveedor S.A.S.",
      taxpayer_type:        "declarante",
      is_withholding_agent: true,
      third_party_autoretainer: false,
      currency:             "COP"
    )

    DocumentItem.create!(
      tax_document:     @document,
      description:      "Servicio de TI",
      quantity:         1,
      unit_price_cents: 5_000_000_00,
      tax_status:       "taxed",
      tax_rate:         @iva_rate
    )

    @document.reload
  end

  test "calcula retención correctamente sobre base gravable" do
    lines = Taxes::WithholdingCalculator.new(@document).call

    assert lines.any?
    rete_line = lines.find { |l| l.tax_type == "retefuente" }
    assert_not_nil rete_line

    # Base = $5,000,000 · Tarifa = 4% · Retención = $200,000
    assert_equal 20_000_000, rete_line.amount_cents
    assert_equal "credit",   rete_line.direction
    assert_equal 4.0,        rete_line.rate_snapshot
  end

  test "NO retiene si la base es menor a la cuantía mínima" do
    # Ítem de $100,000 < 4 UVT ($212,824)
    @document.document_items.destroy_all
    DocumentItem.create!(
      tax_document:     @document,
      description:      "Servicio pequeño",
      quantity:         1,
      unit_price_cents: 10_000_00,
      tax_status:       "taxed",
      tax_rate:         @iva_rate
    )

    lines = Taxes::WithholdingCalculator.new(@document.reload).call
    assert_empty lines
  end

  test "NO retiene si el tercero es autorretenedor" do
    @document.update!(third_party_autoretainer: true)
    lines = Taxes::WithholdingCalculator.new(@document).call
    assert_empty lines
  end

  test "NO retiene si el documento es una factura de venta" do
    @document.update!(document_type: "invoice_sale")
    lines = Taxes::WithholdingCalculator.new(@document).call
    assert_empty lines
  end

  test "NO retiene si el pagador no es agente de retención" do
    @document.update!(is_withholding_agent: false)
    lines = Taxes::WithholdingCalculator.new(@document).call
    assert_empty lines
  end

  test "ítems excluidos no entran en la base de retención" do
    @document.document_items.destroy_all

    DocumentItem.create!(
      tax_document:     @document,
      description:      "Ítem gravado",
      quantity:         1,
      unit_price_cents: 3_000_000_00,
      tax_status:       "taxed",
      tax_rate:         @iva_rate
    )
    DocumentItem.create!(
      tax_document:     @document,
      description:      "Ítem excluido",
      quantity:         1,
      unit_price_cents: 2_000_000_00,
      tax_status:       "excluded"
    )

    lines = Taxes::WithholdingCalculator.new(@document.reload).call
    rete = lines.find { |l| l.tax_type == "retefuente" }

    # ítem gravado: unit_price = 3_000_000_00 cents = $3,000,000 COP
    # ítem excluido NO entra en base → base = 300_000_000 cents
    # retención = 300_000_000 * 4% = 12_000_000 cents = $120,000 COP
    assert_equal 300_000_000, rete.base_cents
    assert_equal  12_000_000, rete.amount_cents
  end

  test "calculation_detail tiene campos de auditoría normativa" do
    lines = Taxes::WithholdingCalculator.new(@document).call
    rete  = lines.find { |l| l.tax_type == "retefuente" }
    detail = rete.calculation_detail_parsed

    assert detail.key?("concept_code")
    assert detail.key?("normativa")
    assert detail.key?("uvt_2026")
    assert detail.key?("formula")
  end
end
