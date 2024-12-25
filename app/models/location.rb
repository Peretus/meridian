class Location < ApplicationRecord
  validates :source, presence: true
  validates :coordinates, presence: true
  validate :validate_coordinate_ranges

  # Helper method to create a point from lon/lat
  def self.create_point(longitude, latitude)
    "POINT(#{longitude} #{latitude})"
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

  # Helper methods to access coordinates
  def longitude
    coordinates&.x
  end

  def latitude
    coordinates&.y
  end

  private

  def validate_coordinate_ranges
    return if coordinates.blank?

    if longitude < -180 || longitude > 180
      errors.add(:coordinates, "longitude must be between -180 and 180")
    end

    if latitude < -90 || latitude > 90
      errors.add(:coordinates, "latitude must be between -90 and 90")
    end
  end
end 