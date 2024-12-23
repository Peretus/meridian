class Location < ApplicationRecord
  validates :source, presence: true
  validates :coordinates, presence: true
  validate :validate_coordinate_ranges

  # Helper method to create a point from lon/lat
  def self.create_point(longitude, latitude)
    "POINT(#{longitude} #{latitude})"
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