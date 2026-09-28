class AddIndexToCompaniesEmail < ActiveRecord::Migration[8.1]
  def change
    add_index :companies, :email, name: "index_companies_on_email"
  end
end
