class CreateQuoteRequestCompaniesAndAddNeighborhood < ActiveRecord::Migration[8.1]
  def change
    add_reference :quote_requests, :neighborhood, foreign_key: true, null: true

    create_table :quote_request_companies do |t|
      t.references :quote_request, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :status, null: false, default: "sent"
      t.datetime :responded_at
      t.text :notes

      t.timestamps
    end

    add_index :quote_request_companies, [ :quote_request_id, :company_id ], unique: true, name: "idx_quote_req_comp_unique"
  end
end
