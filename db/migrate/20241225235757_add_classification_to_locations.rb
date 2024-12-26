class AddClassificationToLocations < ActiveRecord::Migration[7.1]
  def change
    add_column :locations, :classification, :string, default: 'pending'
    add_index :locations, :classification
  end
end
