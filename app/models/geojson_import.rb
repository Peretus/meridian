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
    coordinates_from_file.each do |coords|
      Location.create!(
        coordinates: Location.create_point(coords[0], coords[1]),
        source: 'geojson upload'
      )
    end
  end

  private

  def set_name
    self.name ||= "import_#{Time.current.to_i}"
  end
end 