class GeojsonImport < ApplicationRecord
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
      case feature["geometry"]["type"]
      when "Point"
        coords = feature["geometry"]["coordinates"]
        create_point_if_not_exists(coords[0], coords[1])
      when "LineString"
        feature["geometry"]["coordinates"].each do |coords|
          create_point_if_not_exists(coords[0], coords[1])
        end
      end
    end
  end

  private

  def set_name
    self.name ||= "import_#{Time.current.to_i}"
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
end 