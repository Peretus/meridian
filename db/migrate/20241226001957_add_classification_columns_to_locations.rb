class AddClassificationColumnsToLocations < ActiveRecord::Migration[7.1]
  def change
    add_column :locations, :human_classification, :integer
    add_column :locations, :machine_classification, :integer
  end
end
