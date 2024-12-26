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
            "coordinates": [-122.4194, 37.7749]  # San Francisco
          },
          "properties": {}
        },
        {
          "type": "Feature",
          "geometry": {
            "type": "Point",
            "coordinates": [-73.9352, 40.7306]  # New York
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
            [-122.4194, 37.7749],  # Start in San Francisco
            [-122.4294, 37.7849]   # About 1.2km northwest
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
    
    # With ~484m between points (accounting for 10% overlap), we expect:
    # 2 original points + 2 interpolated points ≈ 1.2km coverage
    assert_difference 'Location.count', 4 do
      import.create_locations
    end
  end

  test "should interpolate points based on image coverage distance" do
    # Delete any existing classifications
    Classification.delete_all
    
    # Clear existing locations to ensure clean state
    Location.delete_all
    
    import = GeojsonImport.new(name: "test_import", display_name: "Test Interpolation")
    file_content = {
      "type": "FeatureCollection",
      "features": [{
        "type": "Feature",
        "geometry": {
          "type": "LineString",
          "coordinates": [
            [-122.4194, 37.7749],  # San Francisco start point
            [-122.4194, 37.7950]   # About 2.2km north, same longitude
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
    
    # With ~484m between points (accounting for 10% overlap):
    # Distance is 2.2km = 2200m
    # Number of segments needed = ceil(2200/483.84) = 5
    # Number of interpolated points = 5 - 1 = 4
    # Total points = 2 endpoints + 4 interpolated = 6
    assert_difference 'Location.count', 6 do
      import.create_locations
    end
    
    # Verify points are between the start and end coordinates
    locations = Location.order(:created_at)
    locations.each do |loc|
      assert_equal -122.4194, loc.longitude.round(4), "Longitude #{loc.longitude} should be -122.4194"
      assert loc.latitude.between?(37.7749, 37.7950), "Latitude #{loc.latitude} not between 37.7749 and 37.7950"
    end
  end
end 