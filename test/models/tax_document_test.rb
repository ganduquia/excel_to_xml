require "test_helper"

class TaxDocumentTest < ActiveSupport::TestCase
  def setup
    @doc = TaxDocument.new(
      document_type:   "invoice_purchase",
      number:          "FV-2026-001",
      issue_date:      Date.new(2026, 3, 6),
      third_party_nit: "900123456-1",
      third_party_name: "Proveedor S.A.S.",
      taxpayer_type:   "declarante",
      is_withholding_agent: true,
      currency:        "COP"
    )
  end

  test "válido con atributos correctos" do
    assert @doc.valid?
  end

  test "inválido con NIT en formato incorrecto" do
    @doc.third_party_nit = "ABCD-1"
    assert_not @doc.valid?
    assert @doc.errors[:third_party_nit].any?
  end

  test "inválido con document_type desconocido" do
    @doc.document_type = "boleta"
    assert_not @doc.valid?
  end

  test "inválido con taxpayer_type desconocido" do
    @doc.taxpayer_type = "persona_especial"
    assert_not @doc.valid?
  end

  test "nota crédito sin documento origen es inválida" do
    @doc.document_type      = "credit_note"
    @doc.original_document  = nil
    assert_not @doc.valid?
    assert @doc.errors[:original_document].any?
  end

  test "purchase? es true para invoice_purchase" do
    assert @doc.purchase?
  end

  test "sale? es true para invoice_sale" do
    @doc.document_type = "invoice_sale"
    assert @doc.sale?
  end

  test "cancelled? es false en estado draft" do
    assert_not @doc.cancelled?
  end

  test "total_to_pay calcula correctamente" do
    @doc.subtotal_cents          = 1_000_000_00
    @doc.total_iva_cents         =   190_000_00
    @doc.total_withholding_cents =    25_000_00
    assert_equal 1_165_000_00, @doc.total_to_pay
  end
end
