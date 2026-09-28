class AddClaimAndUserFieldsToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_reference :companies, :user, foreign_key: true, null: true
    add_column :companies, :claim_status, :string, default: "unclaimed", null: false
    add_column :companies, :is_claimed, :boolean, default: false, null: false
    add_column :companies, :claimed_at, :datetime
    add_column :companies, :claim_expiration_date, :datetime
    add_column :companies, :document_submitted_at, :datetime
    add_column :companies, :document_proof_url, :string
    add_column :companies, :selfie_proof_url, :string
    add_column :companies, :deleted_at, :datetime
    add_column :companies, :removal_requested, :boolean, default: false, null: false
    add_column :companies, :removal_request_name, :string
    add_column :companies, :removal_request_email, :string

    add_index :companies, :deleted_at
    add_index :companies, :claim_status
  end
end
