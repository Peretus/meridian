class AddNotesToClassifications < ActiveRecord::Migration[7.2]
  def change
    add_column :classifications, :notes, :text
  end
end
