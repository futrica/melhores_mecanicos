class CreateStripeTablesAndAddStripeToCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :stripe_products do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :stripe_product_id
      t.text :description
      t.boolean :active, default: true, null: false

      t.timestamps
    end
    add_index :stripe_products, :slug, unique: true
    add_index :stripe_products, :stripe_product_id

    create_table :stripe_prices do |t|
      t.references :stripe_product, null: false, foreign_key: true
      t.string :stripe_price_id
      t.string :name
      t.decimal :amount_cents, precision: 10, scale: 2, default: 0.0, null: false
      t.string :currency, default: "brl", null: false
      t.string :interval, default: "year", null: false
      t.integer :interval_count, default: 12, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end
    add_index :stripe_prices, :stripe_price_id

    create_table :subscriptions do |t|
      t.references :company, null: false, foreign_key: true
      t.references :stripe_price, null: false, foreign_key: true
      t.string :stripe_subscription_id
      t.string :status, default: "active", null: false
      t.datetime :current_period_start
      t.datetime :current_period_end
      t.datetime :canceled_at
      t.datetime :ends_at

      t.timestamps
    end
    add_index :subscriptions, :stripe_subscription_id
    add_index :subscriptions, :status

    change_table :companies, bulk: true do |t|
      t.string :stripe_customer_id
      t.string :card_brand
      t.string :card_last4
      t.string :stripe_payment_method_id
    end
    add_index :companies, :stripe_customer_id
  end
end
