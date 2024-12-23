require "test_helper"

class LocationTest < ActiveSupport::TestCase
  test "valid location with all required attributes" do
    location = locations(:valid_location)
    assert location.valid?
  end

  test "should not save location without coordinates" do
    location = Location.new(source: "test_source")
    assert_not location.valid?
    assert_includes location.errors[:coordinates], "can't be blank"
  end

  test "should not save location without source" do
    location = Location.new(
      coordinates: Location.create_point(-122.47, 37.80)
    )
    assert_not location.valid?
    assert_includes location.errors[:source], "can't be blank"
  end

  test "should accept valid coordinates" do
    location = Location.new(
      coordinates: "POINT(-122.47 37.80)",
      source: "test_source"
    )
    assert location.valid?
  end

  test "longitude returns x coordinate" do
    location = locations(:valid_location)
    assert_equal(-122.47, location.longitude)
  end

  test "latitude returns y coordinate" do
    location = locations(:valid_location)
    assert_equal(37.80, location.latitude)
  end

  test "create_point generates valid point string" do
    longitude = -122.47
    latitude = 37.80
    
    # Generate a point string from coordinates
    point_string = Location.create_point(longitude, latitude)
    
    # Extract the coordinates from the generated string
    # Example point string format: "POINT(-122.47 37.80)"
    coordinates = point_string.match(/POINT\(([-\d.]+) ([-\d.]+)\)/)
    extracted_longitude = coordinates[1].to_f
    extracted_latitude = coordinates[2].to_f
    
    # Verify the extracted coordinates match what we put in
    assert_equal longitude, extracted_longitude
    assert_equal latitude, extracted_latitude
  end
end