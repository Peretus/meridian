class Location < ApplicationRecord
  validates :source, presence: true
  validates :coordinates, presence: true

  # Add logging for debugging
  after_initialize do |location|
    Rails.logger.debug "Location initialized with coordinates: #{coordinates.inspect}"
  end

  before_validation do |location|
    Rails.logger.debug "Location being validated with coordinates: #{coordinates.inspect}"
  end

  before_save do |location|
    Rails.logger.debug "Location being saved with coordinates: #{coordinates.inspect}"
  end

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
end 