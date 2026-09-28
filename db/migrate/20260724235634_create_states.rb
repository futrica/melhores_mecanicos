class CreateStates < ActiveRecord::Migration[8.1]
  def change
    create_table :states do |t|
      t.string :acronym
      t.string :name
      t.string :slug

      t.timestamps
    end
    add_index :states, :acronym, unique: true
    add_index :states, :slug, unique: true
  end
end
