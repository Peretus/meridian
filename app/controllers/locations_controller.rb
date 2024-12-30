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
      @locations = @locations.joins(:classifications)
      case params[:classifier]
      when 'human'
        @locations = @locations.where(classifications: { classifier_type: 'human' })
        if params[:result].present?
          @locations = @locations.where(classifications: { is_result: params[:result] == 'positive' })
        end
      when 'machine'
        @locations = @locations.where(classifications: { classifier_type: 'machine' })
        if params[:result].present?
          @locations = @locations.where(classifications: { is_result: params[:result] == 'positive' })
        end
      end
      
      # Get only the latest classification for each location
      @locations = @locations.where(
        "classifications.created_at = (
          SELECT MAX(created_at) 
          FROM classifications c2 
          WHERE c2.location_id = locations.id 
          AND c2.classifier_type = classifications.classifier_type
        )"
      )
    end

    # Filter for offset points
    if params[:type] == 'offset'
      @locations = @locations.where("source LIKE 'offset_%'")
    end

    # Add counts for training data export
    @positive_count = Location.joins(:classifications)
                            .where(classifications: { classifier_type: 'human', is_result: true })
                            .count
    @negative_count = Location.joins(:classifications)
                            .where(classifications: { classifier_type: 'human', is_result: false })
                            .count
    @can_download_training_data = [@positive_count, @negative_count].min >= 50

    # Filter for conflicts
    if params[:status] == 'conflict'
      @locations = @locations.joins("
        INNER JOIN (
          SELECT c1.location_id
          FROM classifications c1
          INNER JOIN classifications c2
          ON c1.location_id = c2.location_id
          WHERE c1.classifier_type = 'human'
          AND c2.classifier_type = 'machine'
          AND c1.is_result != c2.is_result
          AND c1.created_at = (
            SELECT MAX(c3.created_at)
            FROM classifications c3
            WHERE c3.location_id = c1.location_id
            AND c3.classifier_type = 'human'
          )
          AND c2.created_at = (
            SELECT MAX(c4.created_at)
            FROM classifications c4
            WHERE c4.location_id = c2.location_id
            AND c4.classifier_type = 'machine'
          )
        ) conflicts ON conflicts.location_id = locations.id
      ")
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
          Location.new(
            coordinates: "POINT(#{lon} #{lat})",
            source: 'bulk_upload'
          )
        end

        # First create all locations
        Location.import(locations)

        # Then create classifications if enabled
        locations.each do |location|
          if params[:human_enabled].present?
            location.classifications.create!(
              classifier_type: 'human',
              is_result: params[:human_classification] == '1'
            )
          end

          if params[:machine_enabled].present?
            location.classifications.create!(
              classifier_type: 'machine',
              is_result: params[:machine_classification] == '1'
            )
          end
        end
      end

      redirect_to locations_path, notice: "Successfully imported #{coordinates.length} location#{coordinates.length == 1 ? '' : 's'}"
    rescue => e
      redirect_to bulk_upload_locations_path, alert: "Error importing locations: #{e.message}"
    end
  end

  def classify
    @location = Location.where.not(fetched_at: nil)
                       .where.not(id: Classification.where(classifier_type: 'human').select(:location_id))
                       .order(created_at: :asc)
                       .first

    if @location.nil?
      redirect_to locations_path, notice: 'No more locations to classify!'
    end
  end

  def update_classification
    @location = Location.find(params[:id])
    
    classification = @location.classifications.create!(
      classifier_type: 'human',
      is_result: params[:classification].to_i == 1
    )
    
    if classification.persisted?
      next_location = Location.where.not(fetched_at: nil)
                             .where.not(id: Classification.where(classifier_type: 'human').select(:location_id))
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
    latest_human = @location.classifications.by_human.latest.first
    
    if !latest_human && !@location.classified_by_human?
      render json: { error: 'No human classification to toggle' }, status: :unprocessable_entity
      return
    end

    # Create a new classification with the opposite result
    new_classification = @location.classifications.create!(
      classifier_type: 'human',
      is_result: latest_human ? !latest_human.is_result : true
    )
    
    if new_classification.persisted?
      render json: { 
        success: true, 
        new_classification: new_classification.is_result,
        message: 'Classification updated successfully'
      }
    else
      render json: { error: 'Failed to update classification' }, status: :unprocessable_entity
    end
  end

  def mark_as_anchorage
    @location = Location.find(params[:id])
    latest_machine = @location.classifications.by_machine.latest.first
    
    # Verify this is a machine-negative classification
    unless latest_machine && !latest_machine.is_result
      render json: { error: 'Location is not marked as machine-negative' }, status: :unprocessable_entity
      return
    end

    # Create a new human-positive classification
    new_classification = @location.classifications.create!(
      classifier_type: 'human',
      is_result: true
    )
    
    if new_classification.persisted?
      render json: { 
        success: true, 
        message: 'Location marked as anchorage successfully'
      }
    else
      render json: { error: 'Failed to mark as anchorage' }, status: :unprocessable_entity
    end
  end

  def download_training_data
    require 'zip'

    # Get positive examples with images
    positive = Location.joins(:classifications)
                      .joins(:satellite_image_attachment)  # Only include locations with images
                      .where(classifications: { classifier_type: 'human', is_result: true })
                      .where("classifications.created_at = (
                        SELECT MAX(c2.created_at)
                        FROM classifications c2
                        WHERE c2.location_id = locations.id
                        AND c2.classifier_type = 'human'
                      )")
                      .distinct

    # Get negative examples with images
    negative = Location.joins(:classifications)
                      .joins(:satellite_image_attachment)  # Only include locations with images
                      .where(classifications: { classifier_type: 'human', is_result: false })
                      .where("classifications.created_at = (
                        SELECT MAX(c2.created_at)
                        FROM classifications c2
                        WHERE c2.location_id = locations.id
                        AND c2.classifier_type = 'human'
                      )")
                      .distinct

    pos_count = positive.count
    neg_count = negative.count
    limit = [pos_count, neg_count].min
    
    if limit < 50
      redirect_to classifications_locations_path, 
                  alert: "Not enough classified examples with images available. Need at least 50 of each type. Currently have #{pos_count} positive and #{neg_count} negative examples with images."
      return
    end

    date_str = Time.current.strftime('%Y%m%d')
    
    send_data generate_training_zip(positive.limit(limit), negative.limit(limit), date_str),
              filename: "training_data_#{date_str}.zip",
              type: 'application/zip'
  end

  private

  # This is used on the front-end where we parse coordinates from the 
  # textarea locatd at /locations/bulk_upload
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


  # Uses RubyZip to create a zip file with the training data.
  # Honestly, this can be removed now that we aren't doing training locally anymore
  # but we can keep it around around in case we end up re-implementing training 
  # locally again. Uses RubyZip to create a zip file with the training data.
  def generate_training_zip(positive_locations, negative_locations, date_str)
    Zip::OutputStream.write_buffer do |zip|
      # Add positive examples
      positive_locations.each_with_index do |location, i|
        zip.put_next_entry "training_data_#{date_str}/positive/#{i+1}.png"
        zip.write location.satellite_image.download
      end
      
      # Add negative examples
      negative_locations.each_with_index do |location, i|
        zip.put_next_entry "training_data_#{date_str}/negative/#{i+1}.png"
        zip.write location.satellite_image.download
      end
    end.string
  end
end 