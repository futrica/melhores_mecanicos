class AddTermsFieldsToSubscriptions < ActiveRecord::Migration[8.1]
  def change
    add_column :subscriptions, :accepted_terms_at, :datetime
    add_column :subscriptions, :ip_address, :string
  end
end
