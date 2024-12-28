class AddNotesToLocations < ActiveRecord::Migration[7.2]
  def change
    add_column :locations, :notes, :text
  end
end
