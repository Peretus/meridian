class GeojsonImport < ApplicationRecord
  SKIPPED_WATER_CLASSES = ['O', 'G'].freeze  # O = open water, G = great lakes
  
  # Rough bounding box for contiguous USA
  USA_BOUNDS = {
    min_lon: -124.848974, # Westernmost point
    max_lon: -66.885444,  # Easternmost point
    min_lat: 24.396308,   # Southernmost point
    max_lat: 49.384358    # Northernmost point
  }.freeze

  has_one_attached :file

  validates :name, presence: true
  validates :display_name, presence: true

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

    content = file.download
    parsed_json = JSON.parse(content)
    
    unless parsed_json["type"] == "FeatureCollection" && parsed_json["features"].is_a?(Array)
      raise JSON::ParserError, "Invalid GeoJSON format: must be a FeatureCollection with features"
    end

    parsed_json["features"].each do |feature|
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

  def interpolate_points(start_point, end_point, steps = 10)
    points = []
    
    # Calculate the difference between start and end coordinates
    lon_diff = end_point[0] - start_point[0]
    lat_diff = end_point[1] - start_point[1]
    
    # Create intermediate points
    (1...steps).each do |i|
      ratio = i.to_f / steps
      interpolated_lon = start_point[0] + (lon_diff * ratio)
      interpolated_lat = start_point[1] + (lat_diff * ratio)
      points << [interpolated_lon, interpolated_lat]
    end
    
    points
  end
end 