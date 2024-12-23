require "test_helper"

class GeojsonImportsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get geojson_imports_url
    assert_response :success
  end

  test "should get new" do
    get new_geojson_import_url
    assert_response :success
  end

  test "should create geojson import and locations" do
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

    assert_difference ['GeojsonImport.count', 'Location.count'] do
      post geojson_imports_url, params: {
        geojson_import: {
          display_name: "Test Import",
          file: fixture_file_upload(
            Rails.root.join('test', 'fixtures', 'files', 'test.geojson'),
            'application/geo+json'
          )
        }
      }
    end

    assert_redirected_to geojson_imports_url
    assert_equal 'GeoJSON file was successfully imported.', flash[:notice]
  end

  test "should not create geojson import with invalid params" do
    assert_no_difference ['GeojsonImport.count', 'Location.count'] do
      post geojson_imports_url, params: {
        geojson_import: {
          display_name: "" # Invalid: missing required field
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should handle invalid geojson file" do
    assert_difference 'GeojsonImport.count', 0 do
      post geojson_imports_url, params: {
        geojson_import: {
          display_name: "Invalid GeoJSON",
          file: fixture_file_upload(
            Rails.root.join('test', 'fixtures', 'files', 'invalid.geojson'),
            'application/geo+json'
          )
        }
      }
    end

    assert_response :unprocessable_entity
    assert_equal 'Invalid GeoJSON file format', flash[:alert]
  end
end
