class AddIndexToCompaniesRemovalRequested < ActiveRecord::Migration[8.1]
  def change
    add_index :companies, :removal_requested
    add_index :companies, [ :claim_status, :removal_requested ], name: "idx_companies_claim_status_removal_requested"
  end
end
