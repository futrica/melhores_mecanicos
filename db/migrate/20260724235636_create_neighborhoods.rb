class CreateNeighborhoods < ActiveRecord::Migration[8.1]
  def change
    create_table :neighborhoods do |t|
      t.references :city, null: false, foreign_key: true
      t.string :name
      t.string :slug

      t.timestamps
    end
    add_index :neighborhoods, [ :city_id, :slug ], unique: true
  end
end
