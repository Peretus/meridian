class AddStatusToGeojsonImports < ActiveRecord::Migration[7.1]
  def change
    add_column :geojson_imports, :status, :integer
  end
end
