class TaxDocument < ApplicationRecord
  DOCUMENT_TYPES = %w[invoice_sale invoice_purchase debit_note credit_note].freeze
  TAXPAYER_TYPES = %w[
    declarante no_declarante gran_contribuyente
    autorretenedor regimen_simple no_responsable_iva
  ].freeze
  STATUSES = %w[draft active cancelled].freeze

  has_many :document_items,  dependent: :destroy
  has_many :tax_lines,       dependent: :destroy
  belongs_to :original_document, class_name: "TaxDocument", optional: true
  has_many  :derived_documents,  class_name: "TaxDocument", foreign_key: :original_document_id

  accepts_nested_attributes_for :document_items, allow_destroy: true

  validates :document_type,   presence: true, inclusion: { in: DOCUMENT_TYPES }
  validates :number,          presence: true
  validates :issue_date,      presence: true
  validates :third_party_nit, presence: true, format: { with: /\A\d{6,15}(-\d)?\z/, message: "formato inválido (NIT sin puntos, con o sin dígito de verificación)" }
  validates :third_party_name, presence: true
  validates :taxpayer_type,   presence: true, inclusion: { in: TAXPAYER_TYPES }
  validates :currency,        presence: true
  validates :status,          presence: true, inclusion: { in: STATUSES }
  validate  :original_document_required_for_notes
  validate  :cannot_modify_cancelled_document

  scope :active,    -> { where(status: "active") }
  scope :purchases, -> { where(document_type: "invoice_purchase") }
  scope :sales,     -> { where(document_type: "invoice_sale") }

  def purchase?
    document_type.in?(%w[invoice_purchase debit_note])
  end

  def sale?
    document_type == "invoice_sale"
  end

  def credit_note?
    document_type == "credit_note"
  end

  def cancelled?
    status == "cancelled"
  end

  def draft?
    status == "draft"
  end

  def total_to_pay
    subtotal_cents + total_iva_cents - total_withholding_cents
  end

  # Cancela el documento y todas sus líneas de impuesto
  def cancel!
    raise "Documento ya cancelado" if cancelled?
    update!(status: "cancelled")
    tax_lines.destroy_all
  end

  private

  def original_document_required_for_notes
    return unless document_type.in?(%w[credit_note debit_note])
    errors.add(:original_document, "es requerido para notas crédito y débito") if original_document_id.blank?
  end

  def cannot_modify_cancelled_document
    return unless persisted? && cancelled?
    errors.add(:base, "No se puede modificar un documento cancelado")
  end
end
