module Taxes
  class DashboardController < ApplicationController
    def index
      @total_documents      = TaxDocument.count
      @active_documents     = TaxDocument.where(status: "active").count
      @draft_documents      = TaxDocument.where(status: "draft").count
      @cancelled_documents  = TaxDocument.where(status: "cancelled").count
      @total_tax_rates      = TaxRate.where(active: true).count
      @total_concepts       = WithholdingConcept.where(active: true).count
      @recent_documents     = TaxDocument.order(created_at: :desc).limit(5)
    end
  end
end
