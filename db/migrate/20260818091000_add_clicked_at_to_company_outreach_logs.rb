class AddClickedAtToCompanyOutreachLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :company_outreach_logs, :clicked_at, :datetime
    add_index :company_outreach_logs, :clicked_at
  end
end
