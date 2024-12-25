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
        # Set up signal trap for Ctrl+C
        @interrupted = false
        Signal.trap('INT') do
          @interrupted = true
          Rails.logger.info "Import interrupted by user"
        end

        # Start the import
        @import.create_locations do |progress|
          if @interrupted
            @import.update(status: :interrupted)
            redirect_to geojson_imports_path, alert: 'Import was interrupted'
            return
          end
        end

        redirect_to geojson_imports_path, notice: 'GeoJSON file was successfully imported.'
      rescue JSON::ParserError
        @import.destroy
        flash.now[:alert] = 'Invalid GeoJSON file format'
        render :new, status: :unprocessable_entity
      ensure
        # Reset signal trap to default
        Signal.trap('INT', 'DEFAULT')
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