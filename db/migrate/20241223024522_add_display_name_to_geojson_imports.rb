class AddDisplayNameToGeojsonImports < ActiveRecord::Migration[7.1]
  def change
    add_column :geojson_imports, :display_name, :string
  end
end
