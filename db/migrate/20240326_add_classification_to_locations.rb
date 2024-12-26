class AddClassificationToLocations < ActiveRecord::Migration[7.0]
  def change
    add_column :locations, :classification, :string
    add_index :locations, :classification
  end
end 