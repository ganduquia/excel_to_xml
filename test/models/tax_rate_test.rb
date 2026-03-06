require "test_helper"

class TaxRateTest < ActiveSupport::TestCase
  def setup
    @valid_rate = TaxRate.new(
      name:           "IVA General 19%",
      tax_type:       "iva",
      rate:           19.0,
      effective_from: Date.new(2026, 1, 1),
      active:         true
    )
  end

  test "válido con atributos correctos" do
    assert @valid_rate.valid?
  end

  test "inválido sin nombre" do
    @valid_rate.name = nil
    assert_not @valid_rate.valid?
    assert_includes @valid_rate.errors[:name], "can't be blank"
  end

  test "inválido con tax_type fuera de lista" do
    @valid_rate.tax_type = "igv"
    assert_not @valid_rate.valid?
  end

  test "inválido con tasa negativa" do
    @valid_rate.rate = -1
    assert_not @valid_rate.valid?
  end

  test "inválido si effective_to es anterior a effective_from" do
    @valid_rate.effective_to = Date.new(2025, 12, 31)
    assert_not @valid_rate.valid?
    assert_includes @valid_rate.errors[:effective_to], "debe ser posterior a effective_from"
  end

  test "active_on devuelve tarifa vigente para la fecha" do
    rate = TaxRate.create!(
      name: "IVA 19%", tax_type: "iva", rate: 19.0,
      effective_from: Date.new(2026, 1, 1), active: true
    )
    result = TaxRate.active_on(Date.new(2026, 3, 6), tax_type: "iva")
    assert_equal rate.id, result.id
  end

  test "active_on no devuelve tarifa inactiva" do
    TaxRate.create!(
      name: "IVA 19% inactivo", tax_type: "iva", rate: 19.0,
      effective_from: Date.new(2026, 1, 1), active: false
    )
    result = TaxRate.active_on(Date.new(2026, 3, 6), tax_type: "iva")
    assert_nil result
  end

  test "active_on no devuelve tarifa fuera de vigencia" do
    TaxRate.create!(
      name: "IVA expirado", tax_type: "iva", rate: 19.0,
      effective_from: Date.new(2025, 1, 1),
      effective_to:   Date.new(2025, 12, 31),
      active: true
    )
    result = TaxRate.active_on(Date.new(2026, 3, 6), tax_type: "iva")
    assert_nil result
  end

  test "rate_percent devuelve formato correcto" do
    assert_equal "19.0%", @valid_rate.rate_percent
  end
end
