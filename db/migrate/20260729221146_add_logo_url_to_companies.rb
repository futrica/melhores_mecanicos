class AddLogoUrlToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :logo_url, :string
  end
end
