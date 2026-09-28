class CreateQuoteRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :quote_requests do |t|
      t.references :user, foreign_key: true, null: true
      t.references :company, foreign_key: true, null: true
      t.references :state, foreign_key: true, null: false
      t.references :city, foreign_key: true, null: false
      t.references :category, foreign_key: true, null: true

      t.string :cnae
      t.string :job_site_city, null: false
      t.string :job_site_neighborhood, null: false
      t.string :name, null: false
      t.string :email, null: false
      t.string :phone
      t.text :details
      t.string :status, null: false, default: "pending"

      t.timestamps
    end
  end
end
