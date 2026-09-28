class CreateContactRevealLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :contact_reveal_logs do |t|
      t.references :company, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :contact_type
      t.string :ip_address
      t.string :user_agent
      t.boolean :disclaimer_accepted, default: true, null: false

      t.timestamps
    end
  end
end
