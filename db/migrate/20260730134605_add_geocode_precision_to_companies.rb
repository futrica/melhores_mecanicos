class AddGeocodePrecisionToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :geocode_precision, :string
    add_index :companies, :geocode_precision
  end
end
