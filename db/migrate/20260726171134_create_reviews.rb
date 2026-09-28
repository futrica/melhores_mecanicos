class CreateReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :reviews do |t|
      t.integer :rating, null: false
      t.text :comment
      t.text :tags
      t.string :reviewer_name, null: false
      t.references :user, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true

      t.timestamps
    end

    add_index :reviews, [ :user_id, :company_id ], unique: true
  end
end
