class AddCnaeSecundariosToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :cnae_secundarios, :text
  end
end
