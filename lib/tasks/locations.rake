namespace :locations do
  desc "Fetch satellite images for locations that don't have them yet"
  task :fetch_images, [:limit] => :environment do |t, args|
    limit = (args[:limit] || 10).to_i
    
    locations = Location.where(fetched_at: nil)
                       .order(created_at: :desc)
                       .limit(limit)
    
    puts "Fetching images for #{locations.count} locations..."
    
    locations.each_with_index do |location, index|
      print "Fetching image #{index + 1}/#{locations.count} (ID: #{location.id})... "
      
      if location.fetch_satellite_image
        puts "✓"
      else
        puts "✗"
      end
      
      # Small delay to avoid hitting rate limits
      sleep 0.1
    end
    
    puts "\nDone! Successfully fetched images for #{locations.count} locations."
  end
end 