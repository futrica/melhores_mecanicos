class AddDetailsToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :description, :text
    add_column :companies, :business_hours, :string
  end
end
