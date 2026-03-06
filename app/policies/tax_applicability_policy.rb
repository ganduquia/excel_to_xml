class TaxApplicabilityPolicy
  attr_reader :document

  def initialize(document)
    @document = document
  end

  # La retención se aplica cuando:
  # 1. El documento es una compra (o nota débito)
  # 2. El pagador es agente de retención
  # 3. El proveedor NO es autorretenedor
  def apply_withholding?
    return false unless document.purchase?
    return false unless document.is_withholding_agent?
    return false if document.third_party_autoretainer?
    true
  end

  # ReteIVA aplica cuando el comprador es Gran Contribuyente o entidad estatal
  # y el proveedor es responsable de IVA (no está en no_responsable_iva)
  def apply_reteiva?
    return false unless apply_withholding?
    return false if document.taxpayer_type == "no_responsable_iva"
    document.taxpayer_type == "gran_contribuyente"
  end

  # El IVA aplica solo en ítems marcados como :taxed
  def apply_iva_to?(item)
    item.taxed?
  end

  # Ítems exentos generan TaxLine con amount = 0 (declarativa)
  def declare_exempt?(item)
    item.exempt?
  end
end
