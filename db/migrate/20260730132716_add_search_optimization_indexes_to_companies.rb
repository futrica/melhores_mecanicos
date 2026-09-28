class AddSearchOptimizationIndexesToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_index :companies, [ :state_id, :status, :deleted_at, :is_claimed, :updated_at ], name: "idx_companies_state_search_opt"
    add_index :companies, [ :city_id, :status, :deleted_at, :is_claimed, :updated_at ], name: "idx_companies_city_search_opt"
    add_index :companies, [ :neighborhood_id, :status, :deleted_at, :is_claimed, :updated_at ], name: "idx_companies_neighborhood_search_opt"
  end
end
