# =============================================================================
# SEEDS — Módulo de Impuestos Colombia 2026
# Fuente normativa:
#   - Estatuto Tributario (ET) Arts. 365-401, 424, 437-1, 476, 477
#   - Decreto 1625/2016 (DUT)
#   - UVT 2026: $53,206 COP (estimado sobre base UVT 2025 + inflación DIAN)
#     Verificar con Resolución oficial DIAN al inicio del año fiscal
# =============================================================================

puts ">> Limpiando datos de impuestos..."
TaxLine.delete_all
DocumentItem.delete_all
TaxDocument.delete_all
WithholdingConcept.delete_all
TaxRate.delete_all

UVT_2026 = 53_206  # en pesos — ajustar si DIAN publica valor diferente

# Helper para convertir UVT a centavos
def uvt_to_cents(uvt_count)
  (uvt_count * UVT_2026 * 100).round
end

# =============================================================================
# TARIFAS IVA (Art. 468, 468-1, 477 ET)
# =============================================================================
puts ">> Creando tarifas IVA 2026..."

TaxRate.create!([
  {
    name:           "IVA General 19%",
    tax_type:       "iva",
    rate:           19.0,
    effective_from: Date.new(2017, 1, 1),
    effective_to:   nil,
    active:         true,
    notes:          "Tarifa general Art. 468 ET. Aplica a la mayoría de bienes y servicios gravados."
  },
  {
    name:           "IVA Diferencial 5%",
    tax_type:       "iva",
    rate:           5.0,
    effective_from: Date.new(2017, 1, 1),
    effective_to:   nil,
    active:         true,
    notes:          "Tarifa diferencial Art. 468-1 ET. Aplica a: planes de medicina prepagada, " \
                    "seguros de vida, vehículos híbridos/eléctricos, almacenamiento de gas."
  },
  {
    name:           "IVA Exento 0%",
    tax_type:       "iva",
    rate:           0.0,
    effective_from: Date.new(2017, 1, 1),
    effective_to:   nil,
    active:         true,
    notes:          "Bienes y servicios exentos Art. 477 ET. Generan saldo a favor en declaración. " \
                    "Incluye: carnes, pollos, huevos, libros, cuadernos, exportaciones."
  },
  {
    name:           "ReteIVA Gran Contribuyente 15%",
    tax_type:       "reteiva",
    rate:           15.0,
    effective_from: Date.new(2026, 1, 1),
    effective_to:   nil,
    active:         true,
    notes:          "Retención de IVA Art. 437-1 ET. Grandes contribuyentes retienen 15% del IVA."
  }
])

# =============================================================================
# CONCEPTOS DE RETENCIÓN EN LA FUENTE 2026
# =============================================================================
puts ">> Creando conceptos de retención 2026 (UVT = $#{UVT_2026})..."

EFFECTIVE_FROM_2026 = Date.new(2026, 1, 1)

WithholdingConcept.create!([

  # ── COMPRAS GENERALES ─────────────────────────────────────────────────────
  {
    code:             "0104-COMP-DEC",
    name:             "Compras generales - Declarante",
    rate:             2.5,
    min_amount_cents: uvt_to_cents(27),
    taxpayer_type:    "declarante",
    base_type:        "bruto",
    effective_from:   EFFECTIVE_FROM_2026,
    notes:            "Art. 401 ET. Cuantía mínima 27 UVT ($#{27 * UVT_2026} COP)."
  },
  {
    code:             "0104-COMP-NODEC",
    name:             "Compras generales - No Declarante",
    rate:             3.5,
    min_amount_cents: uvt_to_cents(27),
    taxpayer_type:    "no_declarante",
    base_type:        "bruto",
    effective_from:   EFFECTIVE_FROM_2026,
    notes:            "Art. 401 ET. Personas naturales no obligadas a declarar renta."
  },

  # ── SERVICIOS GENERALES ───────────────────────────────────────────────────
  {
    code:             "0103-SERV-DEC",
    name:             "Servicios generales - Declarante",
    rate:             4.0,
    min_amount_cents: uvt_to_cents(4),
    taxpayer_type:    "declarante",
    base_type:        "bruto",
    effective_from:   EFFECTIVE_FROM_2026,
    notes:            "Art. 392 ET. Cuantía mínima 4 UVT ($#{4 * UVT_2026} COP)."
  },
  {
    code:             "0103-SERV-NODEC",
    name:             "Servicios generales - No Declarante",
    rate:             6.0,
    min_amount_cents: uvt_to_cents(4),
    taxpayer_type:    "no_declarante",
    base_type:        "bruto",
    effective_from:   EFFECTIVE_FROM_2026,
    notes:            "Art. 392 ET. Personas naturales no obligadas a declarar renta."
  },

  # ── HONORARIOS Y COMISIONES ───────────────────────────────────────────────
  {
    code:             "0103-HON-JUR",
    name:             "Honorarios y comisiones - Personas Jurídicas",
    rate:             11.0,
    min_amount_cents: 0,
    taxpayer_type:    "declarante",
    base_type:        "bruto",
    effective_from:   EFFECTIVE_FROM_2026,
    notes:            "Art. 392 ET. Personas jurídicas o asimiladas. Sin cuantía mínima."
  },
  {
    code:             "0103-HON-NAT",
    name:             "Honorarios y comisiones - Personas Naturales Declarantes",
    rate:             10.0,
    min_amount_cents: 0,
    taxpayer_type:    "declarante",
    base_type:        "bruto",
    effective_from:   EFFECTIVE_FROM_2026,
    notes:            "Art. 392 ET. Personas naturales obligadas a declarar. Sin cuantía mínima."
  },

  # ── ARRENDAMIENTOS ────────────────────────────────────────────────────────
  {
    code:             "0105-ARR-INM-DEC",
    name:             "Arrendamiento bienes inmuebles - Declarante",
    rate:             3.5,
    min_amount_cents: uvt_to_cents(27),
    taxpayer_type:    "declarante",
    base_type:        "bruto",
    effective_from:   EFFECTIVE_FROM_2026,
    notes:            "Arrendamientos de inmuebles declarantes. Cuantía mínima 27 UVT."
  },
  {
    code:             "0105-ARR-INM-NODEC",
    name:             "Arrendamiento bienes inmuebles - No Declarante",
    rate:             3.5,
    min_amount_cents: uvt_to_cents(27),
    taxpayer_type:    "no_declarante",
    base_type:        "bruto",
    effective_from:   EFFECTIVE_FROM_2026,
    notes:            "Arrendamientos de inmuebles personas naturales no declarantes."
  },
  {
    code:             "0105-ARR-MUE",
    name:             "Arrendamiento bienes muebles",
    rate:             4.0,
    min_amount_cents: 0,
    taxpayer_type:    "todos",
    base_type:        "bruto",
    effective_from:   EFFECTIVE_FROM_2026,
    notes:            "Arrendamiento de bienes muebles. Sin cuantía mínima."
  },

  # ── SERVICIOS DE ASEO Y VIGILANCIA ───────────────────────────────────────
  {
    code:             "0103-ASEO",
    name:             "Servicios de aseo y vigilancia",
    rate:             2.0,
    min_amount_cents: uvt_to_cents(4),
    taxpayer_type:    "todos",
    base_type:        "bruto",
    effective_from:   EFFECTIVE_FROM_2026,
    notes:            "Art. 392 ET. Base = AIU. Empresas de aseo, vigilancia y temporales."
  },

  # ── TRANSPORTE ────────────────────────────────────────────────────────────
  {
    code:             "0103-TRANS-CARGA",
    name:             "Servicios de transporte de carga",
    rate:             1.0,
    min_amount_cents: uvt_to_cents(4),
    taxpayer_type:    "todos",
    base_type:        "bruto",
    effective_from:   EFFECTIVE_FROM_2026,
    notes:            "Art. 392 ET. Transporte nacional de carga. Cuantía mínima 4 UVT."
  },
  {
    code:             "0103-TRANS-PAS",
    name:             "Servicios de transporte de pasajeros",
    rate:             3.5,
    min_amount_cents: uvt_to_cents(4),
    taxpayer_type:    "todos",
    base_type:        "bruto",
    effective_from:   EFFECTIVE_FROM_2026,
    notes:            "Art. 392 ET. Transporte nacional de pasajeros. Cuantía mínima 4 UVT."
  },

  # ── RENDIMIENTOS FINANCIEROS ──────────────────────────────────────────────
  {
    code:             "0106-REND",
    name:             "Rendimientos financieros e intereses",
    rate:             7.0,
    min_amount_cents: 0,
    taxpayer_type:    "todos",
    base_type:        "bruto",
    effective_from:   EFFECTIVE_FROM_2026,
    notes:            "Art. 395-396 ET. Intereses, descuentos, beneficios y similares."
  },

  # ── LOTERÍAS, RIFAS Y APUESTAS ────────────────────────────────────────────
  {
    code:             "0108-LOTERIA",
    name:             "Loterías, rifas, apuestas y similares",
    rate:             20.0,
    min_amount_cents: uvt_to_cents(48),
    taxpayer_type:    "todos",
    base_type:        "bruto",
    effective_from:   EFFECTIVE_FROM_2026,
    notes:            "Art. 402-404 ET. Cuantía mínima 48 UVT ($#{48 * UVT_2026} COP)."
  },

  # ── RETEIVA GRAN CONTRIBUYENTE ────────────────────────────────────────────
  {
    code:             "RETEIVA-15",
    name:             "ReteIVA Gran Contribuyente 15%",
    rate:             15.0,
    min_amount_cents: 0,
    taxpayer_type:    "gran_contribuyente",
    base_type:        "bruto",
    effective_from:   EFFECTIVE_FROM_2026,
    notes:            "Art. 437-1 ET. Gran Contribuyente retiene 15% del valor del IVA."
  }
])

puts ""
puts "=== Seeds completados 2026 ==="
puts "  TaxRates creadas:            #{TaxRate.count}"
puts "  WithholdingConcepts creados: #{WithholdingConcept.count}"
puts ""
puts "  UVT 2026 usada: $#{UVT_2026} COP"
puts "  Cuantías mínimas:"
puts "    27 UVT (compras/arrendamientos): $#{27 * UVT_2026} COP"
puts "     4 UVT (servicios):              $#{ 4 * UVT_2026} COP"
puts "    48 UVT (loterías):               $#{48 * UVT_2026} COP"
puts ""
puts "  ADVERTENCIA: Verificar UVT 2026 con Resolución oficial DIAN."
