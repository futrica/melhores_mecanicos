class AddPerformanceIndexesToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_index :companies, [ :deleted_at, :claim_status, :updated_at ], name: "idx_companies_deleted_claim_updated"
    add_index :companies, [ :deleted_at, :updated_at ], name: "idx_companies_deleted_updated"
  end
end
