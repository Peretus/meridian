class GeojsonImport < ApplicationRecord
  SKIPPED_WATER_CLASSES = ['O', 'G'].freeze  # O = open water, G = great lakes
  
  # Rough bounding box for contiguous USA
  USA_BOUNDS = {
    min_lon: -124.848974, # Westernmost point
    max_lon: -66.885444,  # Easternmost point
    min_lat: 24.396308,   # Southernmost point
    max_lat: 49.384358    # Northernmost point
  }.freeze

  # Constants for image capture and interpolation
  METERS_PER_PIXEL_AT_ZOOM_16 = 2.4
  IMAGE_SIZE_PIXELS = 224
  OVERLAP_PERCENTAGE = 0.10
  METERS_PER_DEGREE = 111319.9  # 1 degree = 111,319.9 meters at equator

  has_one_attached :file

  validates :name, presence: true
  validates :display_name, presence: true
  
  enum status: { pending: 0, processing: 1, completed: 2, interrupted: 3, failed: 4 }

  before_validation :set_name, on: :create

  def coordinates_from_file
    return [] unless file.attached?

    content = file.download
    parsed_json = JSON.parse(content)
    
    unless parsed_json["type"] == "FeatureCollection" && parsed_json["features"].is_a?(Array)
      raise JSON::ParserError, "Invalid GeoJSON format: must be a FeatureCollection with features"
    end
    
    parsed_json["features"].map do |feature|
      feature["geometry"]["coordinates"]
    end
  end

  def create_locations
    return [] unless file.attached?

    update(status: :processing)
    content = file.download
    parsed_json = JSON.parse(content)
    
    unless parsed_json["type"] == "FeatureCollection" && parsed_json["features"].is_a?(Array)
      raise JSON::ParserError, "Invalid GeoJSON format: must be a FeatureCollection with features"
    end

    total_features = parsed_json["features"].size
    processed_features = 0

    parsed_json["features"].each do |feature|
      # Yield progress if block given
      if block_given?
        progress = (processed_features.to_f / total_features * 100).round
        yield(progress)
      end
      processed_features += 1

      # Skip features that are open water or great lakes
      next if SKIPPED_WATER_CLASSES.include?(feature.dig("properties", "GEO_CLASS"))

      case feature["geometry"]["type"]
      when "Point"
        coords = feature["geometry"]["coordinates"]
        create_point_if_not_exists(coords[0], coords[1]) if point_in_usa?(coords[0], coords[1])
      when "LineString"
        coordinates = feature["geometry"]["coordinates"]
        # Filter coordinates to only those within USA
        usa_coordinates = coordinates.select { |coords| point_in_usa?(coords[0], coords[1]) }
        
        # Create points for each coordinate
        usa_coordinates.each do |coords|
          create_point_if_not_exists(coords[0], coords[1])
        end
        
        # Interpolate between consecutive points that are both in USA
        (0...usa_coordinates.size - 1).each do |i|
          start_point = usa_coordinates[i]
          end_point = usa_coordinates[i + 1]
          
          interpolated_points = interpolate_points(start_point, end_point)
          interpolated_points.each do |point|
            create_point_if_not_exists(point[0], point[1])
          end
        end
      end
    end

    update(status: :completed)
  rescue StandardError => e
    update(status: :failed)
    raise e
  end

  private

  def set_name
    self.name ||= "import_#{Time.current.to_i}"
  end

  def point_in_usa?(longitude, latitude)
    longitude.between?(USA_BOUNDS[:min_lon], USA_BOUNDS[:max_lon]) &&
    latitude.between?(USA_BOUNDS[:min_lat], USA_BOUNDS[:max_lat])
  end

  def create_point_if_not_exists(longitude, latitude)
    point = Location.create_point(longitude, latitude)
    
    # Try to create, skip if similar point exists
    Location.find_or_create_by!(
      coordinates: point,
      source: 'geojson upload'
    )
  rescue ActiveRecord::RecordNotUnique
    # Skip if exact duplicate
    nil
  end

  def interpolate_points(start_point, end_point, steps = nil)
    # Constants for a 224x224 image at zoom level 16 with 10% overlap
    meters_between_points = IMAGE_SIZE_PIXELS * METERS_PER_PIXEL_AT_ZOOM_16 * (1 - OVERLAP_PERCENTAGE)
    
    # Convert points to meters, accounting for latitude in longitude conversion
    avg_lat = (start_point[1] + end_point[1]) / 2
    lon_scale = Math.cos(avg_lat * Math::PI / 180)  # Scale longitude by latitude
    
    start_x = start_point[0] * METERS_PER_DEGREE * lon_scale
    start_y = start_point[1] * METERS_PER_DEGREE
    end_x = end_point[0] * METERS_PER_DEGREE * lon_scale
    end_y = end_point[1] * METERS_PER_DEGREE
    
    # Calculate total distance using both x and y
    dx = end_x - start_x
    dy = end_y - start_y
    total_distance = Math.sqrt(dx * dx + dy * dy)
    
    # Calculate number of points needed based on actual distance
    additional_points = [(total_distance / meters_between_points).ceil - 1, 0].max
    
    points = []
    return points if additional_points == 0
    
    # Create evenly spaced points along both dimensions
    (1..additional_points).each do |i|
      ratio = i.to_f / (additional_points + 1)
      
      # Interpolate both longitude and latitude
      lon = start_point[0] + (end_point[0] - start_point[0]) * ratio
      lat = start_point[1] + (end_point[1] - start_point[1]) * ratio
      
      points << [lon, lat]
    end
    
    points
  end
end 