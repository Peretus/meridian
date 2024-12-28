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
end 