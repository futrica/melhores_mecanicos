class CreateCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :companies do |t|
      t.references :state, null: false, foreign_key: true
      t.references :city, null: false, foreign_key: true
      t.references :neighborhood, null: true, foreign_key: true
      t.string :cnpj
      t.string :legal_name
      t.string :trade_name
      t.string :slug
      t.string :cnae_principal
      t.string :status
      t.string :street
      t.string :number
      t.string :complement
      t.string :zip_code
      t.string :telephone
      t.string :email
      t.float :latitude
      t.float :longitude

      t.timestamps
    end
    add_index :companies, :cnpj, unique: true
    add_index :companies, :slug
    add_index :companies, :status
    add_index :companies, :cnae_principal
  end
end
