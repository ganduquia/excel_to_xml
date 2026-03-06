class DocumentFilter
  attr_reader :params

  def initialize(params)
    @params = params
  end

  def apply(scope)
    scope = filter_by_query(scope)
    scope = filter_by_document_type(scope)
    scope = filter_by_status(scope)
    scope = filter_by_date_from(scope)
    scope = filter_by_date_to(scope)
    scope
  end

  def active?
    query.present? || document_type.present? || status.present? ||
      date_from.present? || date_to.present?
  end

  def query         = params[:q].to_s.strip
  def document_type = params[:document_type].to_s.strip
  def status        = params[:status].to_s.strip
  def date_from     = params[:date_from].to_s.strip
  def date_to       = params[:date_to].to_s.strip

  private

  def filter_by_query(scope)
    return scope if query.blank?
    term = "%#{query}%"
    scope.where(
      "number LIKE :t OR third_party_name LIKE :t OR third_party_nit LIKE :t",
      t: term
    )
  end

  def filter_by_document_type(scope)
    return scope if document_type.blank?
    scope.where(document_type: document_type)
  end

  def filter_by_status(scope)
    return scope if status.blank?
    scope.where(status: status)
  end

  def filter_by_date_from(scope)
    return scope if date_from.blank?
    date = Date.parse(date_from) rescue nil
    date ? scope.where("issue_date >= ?", date) : scope
  end

  def filter_by_date_to(scope)
    return scope if date_to.blank?
    date = Date.parse(date_to) rescue nil
    date ? scope.where("issue_date <= ?", date) : scope
  end
end
