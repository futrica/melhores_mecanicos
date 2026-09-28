class CreateStripeCharges < ActiveRecord::Migration[8.1]
  def change
    create_table :stripe_charges do |t|
      t.references :company, null: false, foreign_key: true
      t.references :subscription, null: true, foreign_key: true
      t.integer :sales_commission_id
      t.string :stripe_charge_id
      t.string :stripe_invoice_id
      t.string :stripe_customer_id
      t.decimal :amount, precision: 10, scale: 2, default: 0.0, null: false
      t.decimal :fee, precision: 10, scale: 2, default: 0.0, null: false
      t.decimal :net, precision: 10, scale: 2, default: 0.0, null: false
      t.string :currency, default: "brl", null: false
      t.string :status, default: "succeeded", null: false
      t.datetime :paid_at
      t.datetime :refunded_at
      t.text :failure_message

      t.timestamps
    end

    add_index :stripe_charges, :stripe_charge_id, unique: true
    add_index :stripe_charges, :stripe_invoice_id
    add_index :stripe_charges, :status
    add_index :stripe_charges, [ :company_id, :status ]
  end
end
