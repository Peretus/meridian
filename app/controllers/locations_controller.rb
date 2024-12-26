class LocationsController < ApplicationController
  def index
    respond_to do |format|
      format.html
      format.json { render json: Location.to_geojson }
    end
  end

  def florida
    respond_to do |format|
      format.html
      format.json { render json: Location.in_florida.to_geojson }
    end
  end

  def gallery
    redirect_to classifications_locations_path, notice: 'The gallery view has been merged into the classifications view'
  end

  def classifications
    @locations = Location.where.not(fetched_at: nil)
    
    # Filter by classifier type and result
    if params[:classifier].present?
      case params[:classifier]
      when 'human'
        @locations = @locations.where.not(human_classification: nil)
        if params[:result].present?
          @locations = @locations.where(human_classification: params[:result] == 'positive' ? 1 : 0)
        end
      when 'machine'
        @locations = @locations.where.not(machine_classification: nil)
        if params[:result].present?
          @locations = @locations.where(machine_classification: params[:result] == 'positive' ? 1 : 0)
        end
      end
    end

    # Filter for conflicts
    if params[:status] == 'conflict'
      @locations = @locations.where.not(human_classification: nil)
                           .where.not(machine_classification: nil)
                           .where('human_classification != machine_classification')
    end

    @locations = @locations.order(created_at: :desc)
                          .page(params[:page])
                          .per(50)

    respond_to do |format|
      format.html
      format.json { render json: @locations.to_geojson }
    end
  end

  def bulk_upload
  end

  def process_bulk_upload
    coordinates_text = params[:coordinates].to_s.strip
    coordinates = parse_coordinates(coordinates_text)
    
    if coordinates.empty?
      redirect_to bulk_upload_locations_path, alert: 'No valid coordinates found in input'
      return
    end

    begin
      Location.transaction do
        locations = coordinates.map do |lat, lon|
          location = Location.new(
            coordinates: "POINT(#{lon} #{lat})",
            source: 'bulk_upload'
          )

          if params[:human_enabled].present?
            location.human_classification = params[:human_classification]
          end

          if params[:machine_enabled].present?
            location.machine_classification = params[:machine_classification]
          end

          location
        end

        Location.import(locations)
      end

      redirect_to locations_path, notice: "Successfully imported #{coordinates.length} location#{coordinates.length == 1 ? '' : 's'}"
    rescue => e
      redirect_to bulk_upload_locations_path, alert: "Error importing locations: #{e.message}"
    end
  end

  def classify
    @location = Location.where(human_classification: nil)
                       .where.not(fetched_at: nil)
                       .order(created_at: :asc)
                       .first

    if @location.nil?
      redirect_to locations_path, notice: 'No more locations to classify!'
    end
  end

  def update_classification
    @location = Location.find(params[:id])
    classification = params[:classification].to_i
    
    if @location.update(human_classification: classification)
      next_location = Location.where(human_classification: nil)
                             .where.not(fetched_at: nil)
                             .order(created_at: :asc)
                             .first

      if next_location
        render json: { redirect_url: classify_locations_path }
      else
        render json: { redirect_url: locations_path, message: 'No more locations to classify!' }
      end
    else
      render json: { error: 'Failed to update classification' }, status: :unprocessable_entity
    end
  end

  def toggle_classification
    @location = Location.find(params[:id])
    
    if @location.human_classification.nil?
      render json: { error: 'Cannot toggle machine classifications' }, status: :unprocessable_entity
      return
    end

    # Toggle the classification between 0 and 1
    @location.human_classification = @location.human_classification == 1 ? 0 : 1
    
    if @location.save
      render json: { 
        success: true, 
        new_classification: @location.human_classification,
        message: 'Classification updated successfully'
      }
    else
      render json: { error: 'Failed to update classification' }, status: :unprocessable_entity
    end
  end

  private

  def parse_coordinates(text)
    # First split by newlines to get each line
    lines = text.split(/\n+/).map(&:strip).reject(&:empty?)
    
    lines.map do |line|
      # Split each line by comma or space
      parts = line.split(/[,\s]+/).map(&:strip).reject(&:empty?)
      next unless parts.length == 2

      lat, lon = parts
      next unless lat && lon

      # Convert to float and validate
      lat_f = lat.to_f
      lon_f = lon.to_f
      
      next unless lat_f.between?(-90, 90) && lon_f.between?(-180, 180)
      
      [lat_f, lon_f]
    end.compact
  end
end 