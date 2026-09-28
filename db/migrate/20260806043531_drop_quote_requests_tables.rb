class DropQuoteRequestsTables < ActiveRecord::Migration[8.1]
  def change
    drop_table :quote_request_companies, if_exists: true
    drop_table :quote_requests, if_exists: true
  end
end
