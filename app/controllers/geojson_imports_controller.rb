class GeojsonImportsController < ApplicationController
  def index
    @imports = GeojsonImport.order(created_at: :desc)
  end

  def new
    @import = GeojsonImport.new
  end

  def create
    @import = GeojsonImport.new(geojson_import_params)
    
    if @import.save
      begin
        @import.create_locations
        redirect_to geojson_imports_path, notice: 'GeoJSON file was successfully imported.'
      rescue JSON::ParserError
        @import.destroy
        flash.now[:alert] = 'Invalid GeoJSON file format'
        render :new, status: :unprocessable_entity
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def geojson_import_params
    params.require(:geojson_import).permit(:display_name, :file)
  end
end