class AddReceitaFieldsToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :opening_date, :date
    add_column :companies, :establishment_type, :string
    add_column :companies, :status_date, :date
    add_column :companies, :capital_social, :decimal
    add_column :companies, :company_size, :string
    add_column :companies, :legal_nature, :string
  end
end
