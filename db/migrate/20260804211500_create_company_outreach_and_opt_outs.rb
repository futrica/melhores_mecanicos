class CreateCompanyOutreachAndOptOuts < ActiveRecord::Migration[7.2]
  def change
    create_table :company_email_opt_outs do |t|
      t.string :email, null: false
      t.bigint :company_id
      t.string :reason
      t.text :feedback
      t.string :token, null: false
      t.datetime :unsubscribed_at

      t.timestamps
    end

    add_index :company_email_opt_outs, :email
    add_index :company_email_opt_outs, :token, unique: true
    add_index :company_email_opt_outs, :company_id

    create_table :company_outreach_logs do |t|
      t.references :company, null: false, foreign_key: true
      t.string :email, null: false
      t.string :campaign_name, null: false, default: "profile_presentation"
      t.datetime :sent_at, null: false
      t.string :status, null: false, default: "sent"

      t.timestamps
    end

    add_index :company_outreach_logs, :email
    add_index :company_outreach_logs, [ :company_id, :campaign_name ]
    add_index :company_outreach_logs, [ :email, :campaign_name ]
  end
end
