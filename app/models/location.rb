class Location < ApplicationRecord
  validates :source, presence: true
  validates :coordinates, presence: true
  validate :validate_coordinate_ranges
  has_one_attached :satellite_image
  has_many :classifications
  has_one_attached :image

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

  def fetch_satellite_image
    return if satellite_image.attached?

    begin
      image_data = GoogleMapsService.new.fetch_static_map(
        latitude: latitude,
        longitude: longitude
      )
      
      satellite_image.attach(
        io: StringIO.new(image_data),
        filename: "satellite_#{id}.jpg",
        content_type: "image/jpeg"
      )

      update(fetched_at: Time.current)
    rescue GoogleMapsService::Error => e
      Rails.logger.error "Failed to fetch satellite image for location #{id}: #{e.message}"
      false
    end
  end

  def latest_classification
    classifications.latest.first
  end

  def is_anchorage?
    latest_human = classifications.by_human.latest.first
    latest_human&.is_result
  end

  def classified?
    classifications.exists?
  end

  def classified_by_machine?
    classifications.by_machine.exists?
  end

  def classified_by_human?
    classifications.by_human.exists?
  end

  def classification_result
    latest_classification&.result
  end

  # Class methods for finding locations by classification
  def self.anchorages
    joins(:classifications)
      .where(classifications: { classifier_type: 'human', is_result: true })
      .where("classifications.created_at = (
        SELECT MAX(c2.created_at)
        FROM classifications c2
        WHERE c2.location_id = locations.id
        AND c2.classifier_type = 'human'
      )")
      .distinct
  end

  def self.not_anchorages
    joins(:classifications)
      .where(classifications: { classifier_type: 'human', is_result: false })
      .where("classifications.created_at = (
        SELECT MAX(c2.created_at)
        FROM classifications c2
        WHERE c2.location_id = locations.id
        AND c2.classifier_type = 'human'
      )")
      .distinct
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