class AddUniqueIndexToLocations < ActiveRecord::Migration[7.1]
  def change
    add_index :locations, :coordinates, unique: true, using: :gist
  end
end 