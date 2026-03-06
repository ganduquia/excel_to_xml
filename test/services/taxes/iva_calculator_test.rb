require "test_helper"

class Taxes::IvaCalculatorTest < ActiveSupport::TestCase
  def setup
    @iva_rate = TaxRate.create!(
      name:           "IVA 19%",
      tax_type:       "iva",
      rate:           19.0,
      effective_from: Date.new(2026, 1, 1),
      active:         true
    )

    @iva_5_rate = TaxRate.create!(
      name:           "IVA 5%",
      tax_type:       "iva",
      rate:           5.0,
      effective_from: Date.new(2026, 1, 1),
      active:         true
    )

    @document = TaxDocument.create!(
      document_type:    "invoice_sale",
      number:           "FV-2026-TEST",
      issue_date:       Date.new(2026, 3, 6),
      third_party_nit:  "800200400-1",
      third_party_name: "Cliente S.A.",
      taxpayer_type:    "declarante",
      currency:         "COP"
    )
  end

  test "ítem gravado genera TaxLine con IVA correcto" do
    item = DocumentItem.create!(
      tax_document:    @document,
      description:     "Servicio de consultoría",
      quantity:        1,
      unit_price_cents: 1_000_000_00,
      tax_status:      "taxed",
      tax_rate:        @iva_rate
    )

    lines = Taxes::IvaCalculator.new(@document.reload).call

    assert_equal 1, lines.size
    assert_equal "iva",    lines.first.tax_type
    assert_equal "charge", lines.first.direction
    assert_equal 19_000_000, lines.first.amount_cents  # 19% de $1,000,000
    assert_equal 19.0,     lines.first.rate_snapshot
  end

  test "ítem excluido NO genera TaxLine" do
    DocumentItem.create!(
      tax_document:    @document,
      description:     "Medicamento excluido",
      quantity:        1,
      unit_price_cents: 500_000_00,
      tax_status:      "excluded"
    )

    lines = Taxes::IvaCalculator.new(@document.reload).call
    assert_empty lines
  end

  test "ítem exento genera TaxLine con amount = 0" do
    DocumentItem.create!(
      tax_document:    @document,
      description:     "Libro exento Art. 477 ET",
      quantity:        1,
      unit_price_cents: 80_000_00,
      tax_status:      "exempt"
    )

    lines = Taxes::IvaCalculator.new(@document.reload).call

    assert_equal 1, lines.size
    assert_equal 0,   lines.first.amount_cents
    assert_equal 0.0, lines.first.rate_snapshot
  end

  test "descuento reduce la base gravable del IVA" do
    item = DocumentItem.create!(
      tax_document:    @document,
      description:     "Producto con descuento",
      quantity:        1,
      unit_price_cents: 1_000_000_00,
      discount_cents:    100_000_00,
      tax_status:      "taxed",
      tax_rate:        @iva_rate
    )

    lines = Taxes::IvaCalculator.new(@document.reload).call

    # Base = 1,000,000 - 100,000 = 900,000
    # IVA  = 900,000 * 19% = 171,000
    assert_equal 17_100_000, lines.first.amount_cents
    assert_equal 90_000_000, lines.first.base_cents
  end

  test "múltiples ítems generan múltiples TaxLines" do
    DocumentItem.create!(
      tax_document: @document, description: "Ítem 1",
      quantity: 2, unit_price_cents: 500_000_00,
      tax_status: "taxed", tax_rate: @iva_rate
    )
    DocumentItem.create!(
      tax_document: @document, description: "Ítem 2 - 5%",
      quantity: 1, unit_price_cents: 200_000_00,
      tax_status: "taxed", tax_rate: @iva_5_rate
    )
    DocumentItem.create!(
      tax_document: @document, description: "Ítem 3 - excluido",
      quantity: 1, unit_price_cents: 300_000_00,
      tax_status: "excluded"
    )

    lines = Taxes::IvaCalculator.new(@document.reload).call

    # 2 gravados + 0 excluidos = 2 líneas
    assert_equal 2, lines.size
    iva_19 = lines.find { |l| l.rate_snapshot == 19.0 }
    iva_5  = lines.find { |l| l.rate_snapshot == 5.0 }

    assert_equal 19_000_000, iva_19.amount_cents  # 1,000,000 * 19%
    assert_equal  1_000_000, iva_5.amount_cents   # 200,000 * 5%
  end

  test "calculation_detail incluye datos de auditoría" do
    DocumentItem.create!(
      tax_document: @document, description: "Auditoría test",
      quantity: 1, unit_price_cents: 1_000_000_00,
      tax_status: "taxed", tax_rate: @iva_rate
    )

    lines = Taxes::IvaCalculator.new(@document.reload).call
    detail = lines.first.calculation_detail_parsed

    assert detail.key?("formula")
    assert detail.key?("rate")
    assert detail.key?("base_cents")
    assert detail.key?("issue_date")
  end
end
