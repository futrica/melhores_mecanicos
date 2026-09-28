class CreateCities < ActiveRecord::Migration[8.1]
  def change
    create_table :cities do |t|
      t.references :state, null: false, foreign_key: true
      t.string :name
      t.string :slug
      t.string :ibge_code

      t.timestamps
    end
    add_index :cities, [ :state_id, :slug ], unique: true
    add_index :cities, :ibge_code
  end
end
