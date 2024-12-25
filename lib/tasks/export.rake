namespace :export do
  desc "Export all locations to a GeoJSON file"
  task :locations_to_geojson, [:filename] => :environment do |t, args|
    filename = args[:filename] || "locations_export_#{Time.current.strftime('%Y%m%d_%H%M%S')}.geojson"
    
    File.write(filename, Location.to_geojson)
    puts "Exported #{Location.count} locations to #{filename}"
  end
end 