class Location < ApplicationRecord
  validates :source, presence: true
  validates :coordinates, presence: true
  validate :validate_coordinate_ranges

  FLORIDA_BOUNDS = {
    min_lat: 24.3959,
    max_lat: 31.0011,
    min_lon: -87.6349,
    max_lon: -79.9743
  }.freeze

  # Helper method to create a point from lon/lat
  def self.create_point(longitude, latitude)
    "POINT(#{longitude} #{latitude})"
  end

  # Find all locations within Florida's bounding box
  def self.in_florida
    where(
      "ST_Y(coordinates::geometry) BETWEEN ? AND ? AND ST_X(coordinates::geometry) BETWEEN ? AND ?",
      FLORIDA_BOUNDS[:min_lat],
      FLORIDA_BOUNDS[:max_lat],
      FLORIDA_BOUNDS[:min_lon],
      FLORIDA_BOUNDS[:max_lon]
    )
  end

  # Export all locations as GeoJSON
  def self.to_geojson
    {
      type: "FeatureCollection",
      features: all.map(&:to_geojson_feature)
    }.to_json
  end

  # Export a single location as a GeoJSON feature
  def to_geojson_feature
    {
      type: "Feature",
      geometry: {
        type: "Point",
        coordinates: [longitude, latitude]
      },
      properties: {
        id: id,
        source: source,
        created_at: created_at,
        fetched_at: fetched_at
      }
    }
  end

  # Get the longitude (x coordinate)
  def longitude
    return nil unless coordinates
    coordinates.x
  end

  # Get the latitude (y coordinate)
  def latitude
    return nil unless coordinates
    coordinates.y
  end

  private

  def validate_coordinate_ranges
    return unless coordinates

    if longitude < -180 || longitude > 180
      errors.add(:coordinates, "longitude must be between -180 and 180")
    end

    if latitude < -90 || latitude > 90
      errors.add(:coordinates, "latitude must be between -90 and 90")
    end
  end
end 