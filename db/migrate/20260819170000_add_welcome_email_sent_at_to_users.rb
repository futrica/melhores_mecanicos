class AddWelcomeEmailSentAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :welcome_email_sent_at, :datetime
  end
end
