class CreateGeojsonImports < ActiveRecord::Migration[7.0]
  def change
    create_table :geojson_imports do |t|
      t.string :name, null: false
      t.string :display_name, null: false
      t.timestamps
    end
  end
end 