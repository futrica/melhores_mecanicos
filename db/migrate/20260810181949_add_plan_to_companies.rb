class AddPlanToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :plan, :string, default: "free", null: false
  end
end
