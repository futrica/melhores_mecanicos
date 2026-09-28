class CreatePartners < ActiveRecord::Migration[8.1]
  def change
    create_table :partners do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name
      t.string :document
      t.string :qualification
      t.date :entry_date
      t.string :person_type
      t.string :age_range

      t.timestamps
    end
  end
end
