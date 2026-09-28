class AddConfirmableAndPhoneToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :phone, :string
    add_column :users, :confirmation_token, :string
    add_column :users, :confirmed_at, :datetime
    add_column :users, :confirmation_sent_at, :datetime
    add_column :users, :unconfirmed_email, :string

    add_index :users, :confirmation_token, unique: true

    # Confirm existing users so current data remains valid
    reversible do |dir|
      dir.up do
        User.update_all(confirmed_at: Time.current)
      end
    end
  end
end
