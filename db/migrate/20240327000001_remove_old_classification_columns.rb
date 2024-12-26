class RemoveOldClassificationColumns < ActiveRecord::Migration[7.1]
  def change
    remove_column :locations, :classification
    remove_column :locations, :human_classification
    remove_column :locations, :machine_classification
  end
end 