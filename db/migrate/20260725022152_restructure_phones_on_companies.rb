class RestructurePhonesOnCompanies < ActiveRecord::Migration[8.1]
  def change
    remove_column :companies, :telephone, :string
    add_column :companies, :phone_1, :string
    add_column :companies, :phone_2, :string
    add_column :companies, :phone_1_whatsapp, :boolean, default: false
    add_column :companies, :phone_2_whatsapp, :boolean, default: false
  end
end
