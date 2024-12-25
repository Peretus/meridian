require 'test_helper'

class GeojsonImportTest < ActiveSupport::TestCase
  test "should not save geojson import without display_name" do
    import = GeojsonImport.new
    assert_not import.save, "Saved the import without a display name"
  end

  test "should auto-generate name if not provided" do
    import = GeojsonImport.new(display_name: "My Import")
    assert import.save
    assert_match /^import_\d+$/, import.name
  end

  test "should save with valid geojson file" do
    import = GeojsonImport.new(display_name: "San Francisco Points")
    file_content = {
      "type": "FeatureCollection",
      "features": [{
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [-122.4194, 37.7749]
        },
        "properties": {}
      }]
    }.to_json

    import.file.attach(
      io: StringIO.new(file_content),
      filename: "valid.geojson",
      content_type: "application/geo+json"
    )
    assert import.save
  end

  test "should read coordinates from uploaded geojson" do
    import = GeojsonImport.new(display_name: "Test Coordinates")
    file_content = {
      "type": "FeatureCollection",
      "features": [{
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [-122.4194, 37.7749]
        },
        "properties": {}
      }]
    }.to_json

    import.file.attach(
      io: StringIO.new(file_content),
      filename: "coordinates.geojson",
      content_type: "application/geo+json"
    )
    import.save!
    
    assert_equal [-122.4194, 37.7749], import.coordinates_from_file.first
  end

  test "should handle invalid json gracefully" do
    import = GeojsonImport.new(display_name: "Invalid JSON")
    import.file.attach(
      io: StringIO.new("{ invalid json }"),
      filename: "invalid.geojson",
      content_type: "application/geo+json"
    )
    import.save!
    
    assert_raises(JSON::ParserError) { import.coordinates_from_file }
  end

  test "should create locations from geojson" do
    import = GeojsonImport.new(display_name: "Test Import")
    file_content = {
      "type": "FeatureCollection",
      "features": [{
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [-122.4194, 37.7749]
        },
        "properties": {}
      }]
    }.to_json

    import.file.attach(
      io: StringIO.new(file_content),
      filename: "locations.geojson",
      content_type: "application/geo+json"
    )
    import.save!

    assert_difference 'Location.count' do
      import.create_locations
    end

    location = Location.last
    assert_equal -122.4194, location.longitude
    assert_equal 37.7749, location.latitude
    assert_equal 'geojson upload', location.source
  end

  test "should handle multiple points in geojson" do
    import = GeojsonImport.new(display_name: "Multiple Points")
    file_content = {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "geometry": {
            "type": "Point",
            "coordinates": [-122.4194, 37.7749]
          },
          "properties": {}
        },
        {
          "type": "Feature",
          "geometry": {
            "type": "Point",
            "coordinates": [-0.1276, 51.5074]
          },
          "properties": {}
        }
      ]
    }.to_json

    import.file.attach(
      io: StringIO.new(file_content),
      filename: "multiple.geojson",
      content_type: "application/geo+json"
    )
    import.save!

    assert_difference 'Location.count', 2 do
      import.create_locations
    end
  end

  test "should handle duplicate points idempotently" do
    import = GeojsonImport.new(display_name: "Test Import")
    file_content = {
      "type": "FeatureCollection",
      "features": [{
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [-122.4194, 37.7749]
        },
        "properties": {}
      }]
    }.to_json

    import.file.attach(
      io: StringIO.new(file_content),
      filename: "coordinates.geojson",
      content_type: "application/geo+json"
    )
    import.save!
    
    # First import should create location
    assert_difference 'Location.count', 1 do
      import.create_locations
    end
    
    # Second import should not create duplicate
    assert_no_difference 'Location.count' do
      import.create_locations
    end
  end

  test "should handle linestring features" do
    import = GeojsonImport.new(display_name: "Test LineString")
    file_content = {
      "type": "FeatureCollection",
      "features": [{
        "type": "Feature",
        "geometry": {
          "type": "LineString",
          "coordinates": [
            [-122.4194, 37.7749],
            [-122.4200, 37.7750]
          ]
        },
        "properties": {}
      }]
    }.to_json

    import.file.attach(
      io: StringIO.new(file_content),
      filename: "linestring.geojson",
      content_type: "application/geo+json"
    )
    import.save!
    
    assert_difference 'Location.count', 11 do  # 2 original points + 9 interpolated points
      import.create_locations
    end
  end

  test "should interpolate points between linestring coordinates" do
    # Clear existing locations to ensure clean state
    Location.delete_all
    
    import = GeojsonImport.new(display_name: "Test Interpolation")
    file_content = {
      "type": "FeatureCollection",
      "features": [{
        "type": "Feature",
        "geometry": {
          "type": "LineString",
          "coordinates": [
            [-122.4194, 37.7749],  # San Francisco start point
            [-122.4194, 37.7800]   # A point slightly north, same longitude
          ]
        },
        "properties": {}
      }]
    }.to_json

    import.file.attach(
      io: StringIO.new(file_content),
      filename: "interpolation.geojson",
      content_type: "application/geo+json"
    )
    import.save!
    
    # Should create original points plus interpolated points
    assert_difference 'Location.count', 11 do  # 2 original points + 9 interpolated points
      import.create_locations
    end
    
    # Verify points are between the start and end coordinates
    locations = Location.order(:created_at)
    locations.each do |loc|
      assert_equal -122.4194, loc.longitude, "Longitude #{loc.longitude} should be -122.4194"
      assert loc.latitude.between?(37.7749, 37.7800), "Latitude #{loc.latitude} not between 37.7749 and 37.7800"
    end
  end
end 