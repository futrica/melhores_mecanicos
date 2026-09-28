class AddCountersToCompaniesCitiesAndNeighborhoods < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :views_count, :integer, default: 0, null: false
    add_column :cities, :searches_count, :integer, default: 0, null: false
    add_column :neighborhoods, :searches_count, :integer, default: 0, null: false
  end
end
