namespace :ml do
  desc "Run ML classifier on unclassified locations"
  task classify: :environment do
    # First check if there are any unclassified locations
    unclassified_count = Location.joins(:satellite_image_attachment)
                             .left_joins(:classifications)
                             .where(classifications: { id: nil })
                             .distinct
                             .count

    if unclassified_count.zero?
      total_with_images = Location.joins(:satellite_image_attachment).count
      total_classified = Location.joins(:classifications).distinct.count
      
      puts "\nNo unclassified locations found:"
      puts "- Total locations with satellite images: #{total_with_images}"
      puts "- Locations already classified: #{total_classified}"
      puts "\nAll locations with satellite images have been classified! 🎉"
      exit 0
    end

    # Start the Node.js model server
    unless Ml::ClassifierService.start_server
      puts "Failed to start model server. Please check the logs in log/node_service.log"
      exit 1
    end
    
    puts "Model server is ready!"
    
    begin
      # Run the classifier
      Ml::ClassifierService.classify_unclassified_locations
    rescue => e
      puts "Error: #{e.message}"
      exit 1
    end
  end

  desc "Test image processing with a single location"
  task test_image: :environment do
    # Get the first unclassified location with an image
    location = Location.joins(:satellite_image_attachment)
                     .left_joins(:classifications)
                     .where(classifications: { id: nil })
                     .first

    if location.nil?
      puts "No unclassified locations with images found"
      exit 1
    end

    puts "Testing image processing for location #{location.id}..."
    
    # Start the Node.js model server
    unless Ml::ClassifierService.start_server
      puts "Failed to start model server. Please check the logs in log/node_service.log"
      exit 1
    end
    
    puts "Model server is ready!"
    
    # Test the image processing
    if Ml::ClassifierService.test_image_processing(location)
      puts "Image processing test successful!"
    else
      puts "Image processing test failed!"
    end
  end

  desc "Fetch missing satellite images for locations"
  task fetch_images: :environment do
    Location.fetch_missing_satellite_images
  end

  desc "Test image quality with different scale parameters"
  task test_image_quality: :environment do
    require 'fileutils'
    require 'mini_magick'

    # Create test directory
    test_dir = Rails.root.join('tmp', 'image_quality_test')
    FileUtils.mkdir_p(test_dir)
    
    # Get 3 random human-classified anchorages using raw SQL for the random selection
    test_locations = Location.find_by_sql([
      "SELECT DISTINCT ON (locations.id) locations.* 
       FROM locations 
       INNER JOIN classifications ON classifications.location_id = locations.id 
       WHERE classifications.classifier_type = 'human' 
       AND classifications.is_result = true 
       ORDER BY locations.id, RANDOM() 
       LIMIT 3"
    ])
    
    puts "\nFetching test images for #{test_locations.count} locations..."
    
    test_locations.each_with_index do |location, index|
      puts "\nLocation #{index + 1}:"
      puts "ID: #{location.id}"
      puts "Coordinates: #{location.latitude}, #{location.longitude}"
      
      # Fetch both scale=1 and scale=2 images
      service = GoogleMapsService.new
      
      # Scale 1 (original)
      scale1_data = service.fetch_static_map(
        latitude: location.latitude,
        longitude: location.longitude,
        size: "224x224"
      )
      
      # Scale 2 (high res)
      scale2_data = service.fetch_static_map(
        latitude: location.latitude,
        longitude: location.longitude,
        size: "224x224",
        scale: 2
      )
      
      # Save original scale=1 image
      scale1_path = test_dir.join("location_#{location.id}_scale1.png")
      File.open(scale1_path, 'wb') do |f|
        f.write(scale1_data)
      end
      
      # Save original scale=2 image
      scale2_path = test_dir.join("location_#{location.id}_scale2_original.png")
      File.open(scale2_path, 'wb') do |f|
        f.write(scale2_data)
      end
      
      # Downsample scale=2 image to 224x224 with high quality settings
      image = MiniMagick::Image.read(scale2_data)
      image.combine_options do |c|
        c.resize "224x224"
        c.filter "Lanczos"
        c.quality "100"
      end
      image.write test_dir.join("location_#{location.id}_scale2_downsampled.png")
      
      puts "Images saved to #{test_dir}:"
      puts "- scale1.png: Original 224x224"
      puts "- scale2_original.png: High-res 448x448"
      puts "- scale2_downsampled.png: High-res downsampled to 224x224"
    end
    
    puts "\nTest images have been generated in #{test_dir}"
    puts "For each location, compare:"
    puts "1. scale1.png (original) vs scale2_downsampled.png (high-res downsampled)"
    puts "2. scale2_original.png shows the raw high-res version for reference"
  end
end 