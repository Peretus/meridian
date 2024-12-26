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

  test "should not save location with invalid longitude" do
    location = Location.new(
      coordinates: Location.create_point(-181, 37.80),
      source: "test_source"
    )
    assert_not location.valid?
    assert_includes location.errors[:coordinates], "longitude must be between -180 and 180"

    location.coordinates = Location.create_point(181, 37.80)
    assert_not location.valid?
    assert_includes location.errors[:coordinates], "longitude must be between -180 and 180"
  end

  test "should not save location with invalid latitude" do
    location = Location.new(
      coordinates: Location.create_point(-122.47, 91),
      source: "test_source"
    )
    assert_not location.valid?
    assert_includes location.errors[:coordinates], "latitude must be between -90 and 90"

    location.coordinates = Location.create_point(-122.47, -91)
    assert_not location.valid?
    assert_includes location.errors[:coordinates], "latitude must be between -90 and 90"
  end

  test "should export to geojson" do
    # Clear existing locations and classifications
    Classification.delete_all
    Location.delete_all
    
    # Create a test location
    location = Location.create!(
      coordinates: Location.create_point(-122.4194, 37.7749),
      source: "test_source",
      fetched_at: Time.current
    )
    
    # Export to GeoJSON
    geojson = JSON.parse(Location.to_geojson)
    
    # Verify GeoJSON structure
    assert_equal "FeatureCollection", geojson["type"]
    assert_equal 1, geojson["features"].length
    
    feature = geojson["features"].first
    assert_equal "Feature", feature["type"]
    assert_equal "Point", feature["geometry"]["type"]
    assert_equal [-122.4194, 37.7749], feature["geometry"]["coordinates"]
    assert_equal "test_source", feature["properties"]["source"]
    assert_equal location.id, feature["properties"]["id"]
  end

  test "is_anchorage? returns correct value" do
    location = locations(:valid_location)
    assert location.is_anchorage?  # Has human_positive classification

    location = locations(:one)
    assert_not location.is_anchorage?  # Has human_negative classification
  end

  test "classified? returns correct value" do
    location = locations(:valid_location)
    assert location.classified?

    location = Location.create!(
      coordinates: Location.create_point(-122.47, 37.80),
      source: "test_source"
    )
    assert_not location.classified?
  end

  test "classified_by_human? returns correct value" do
    location = locations(:valid_location)
    assert location.classified_by_human?

    location = Location.create!(
      coordinates: Location.create_point(-122.47, 37.80),
      source: "test_source"
    )
    assert_not location.classified_by_human?
  end

  test "classified_by_machine? returns correct value" do
    location = locations(:valid_location)
    assert location.classified_by_machine?

    location = Location.create!(
      coordinates: Location.create_point(-122.47, 37.80),
      source: "test_source"
    )
    assert_not location.classified_by_machine?
  end

  test "anchorages scope returns correct locations" do
    assert_includes Location.anchorages, locations(:valid_location)
    assert_not_includes Location.anchorages, locations(:one)
  end

  test "not_anchorages scope returns correct locations" do
    assert_includes Location.not_anchorages, locations(:one)
    assert_not_includes Location.not_anchorages, locations(:valid_location)
  end
end