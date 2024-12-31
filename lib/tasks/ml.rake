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
      puts "Failed to start model server. Please check the logs in log/image_classification_service.log"
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
      puts "Failed to start model server. Please check the logs in log/image_classification_service.log"
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

  desc "Re-fetch high quality images for human-classified anchorages"
  task refetch_anchorage_images: :environment do
    require 'mini_magick'

    # Get all human-classified anchorages
    locations = Location.anchorages
    total = locations.count
    
    puts "\nFound #{total} human-classified anchorages. Starting high-quality image fetch..."
    puts "This will:"
    puts "1. Fetch images at 448x448 (scale=2)"
    puts "2. Store in PNG format"
    puts "3. Apply Lanczos downsampling to 224x224"
    puts "\nProgress:"
    
    success = 0
    errors = 0
    
    locations.find_each.with_index do |location, index|
      print "\rProcessing #{index + 1}/#{total} (#{((index + 1).to_f / total * 100).round(1)}%)"
      
      begin
        # Fetch high-res image
        service = GoogleMapsService.new
        image_data = service.fetch_static_map(
          latitude: location.latitude,
          longitude: location.longitude,
          size: "224x224",
          scale: 2
        )
        
        # Process with high quality settings
        image = MiniMagick::Image.read(image_data)
        image.format 'png'
        image.combine_options do |c|
          c.resize "224x224"
          c.filter "Lanczos"
          c.quality "100"
        end
        
        # Prepare processed image for attachment
        processed_image = StringIO.new
        processed_image.write(image.to_blob)
        processed_image.rewind
        
        # Remove old image and attach new one
        location.satellite_image.purge if location.satellite_image.attached?
        location.satellite_image.attach(
          io: processed_image,
          filename: "satellite_#{location.id}.png",
          content_type: "image/png"
        )
        
        location.update(fetched_at: Time.current)
        success += 1
        
      rescue => e
        errors += 1
        puts "\nError processing location #{location.id}: #{e.message}"
      end
      
      # Add a small delay to respect rate limits
      sleep(0.1)
    end
    
    puts "\n\nProcess complete!"
    puts "Successfully processed: #{success}"
    puts "Errors: #{errors}"
    puts "\nAll done! 🎉"
  end

  desc "Remove satellite images fetched before the specified time"
  task :remove_old_images, [:minutes_ago] => :environment do |t, args|
    minutes = (args[:minutes_ago] || 15).to_i
    cutoff_time = Time.current - minutes.minutes
    
    # Find locations with old images
    locations = Location.where("fetched_at < ?", cutoff_time)
                      .joins(:satellite_image_attachment)
                      .distinct
    
    total = locations.count
    return if total.zero?
    
    puts "\nFound #{total} locations with images older than #{minutes} minutes ago"
    puts "Starting cleanup..."
    
    success = 0
    errors = 0
    
    locations.find_each.with_index do |location, index|
      print "\rProcessing #{index + 1}/#{total} (#{((index + 1).to_f / total * 100).round(1)}%)"
      
      begin
        # Remove the image and reset fetched_at
        location.satellite_image.purge
        location.update_columns(fetched_at: nil)
        success += 1
      rescue => e
        errors += 1
        puts "\nError processing location #{location.id}: #{e.message}"
      end
    end
    
    puts "\n\nCleanup complete!"
    puts "Successfully removed: #{success} images"
    puts "Errors: #{errors}"
    puts "\nYou can now run 'rake ml:refetch_anchorage_images' to fetch high-quality images"
  end

  desc "Generate offset points around anchorages for additional training data"
  task :generate_offset_points, [:meters] => :environment do |t, args|
    meters = (args[:meters] || 100).to_i
    
    # Convert meters to degrees (approximate at mid-latitudes)
    # 1 degree latitude = ~111km, 1 degree longitude varies with latitude
    lat_offset = meters.to_f / 111_000  # Convert meters to degrees latitude
    
    puts "\nGenerating points offset by #{meters} meters in each cardinal direction..."
    
    # Get all human-classified anchorages
    locations = Location.anchorages
    total = locations.count
    
    puts "Found #{total} anchorages to process"
    puts "This will create 4 new points around each anchorage"
    puts "Estimated new points to create: #{total * 4}"
    
    success = 0
    errors = 0
    
    locations.find_each.with_index do |location, index|
      print "\rProcessing #{index + 1}/#{total} (#{((index + 1).to_f / total * 100).round(1)}%)"
      
      begin
        # Calculate longitude offset based on latitude (compensate for earth's curvature)
        lng_offset = lat_offset / Math.cos(location.latitude * Math::PI / 180)
        
        # Create offset points
        offsets = [
          { direction: 'north', lat: lat_offset, lng: 0 },
          { direction: 'south', lat: -lat_offset, lng: 0 },
          { direction: 'east', lat: 0, lng: lng_offset },
          { direction: 'west', lat: 0, lng: -lng_offset }
        ]
        
        offsets.each do |offset|
          new_location = Location.create!(
            coordinates: "POINT(#{location.longitude + offset[:lng]} #{location.latitude + offset[:lat]})",
            source: "offset_#{offset[:direction]}_#{meters}m_from_#{location.id}",
            notes: "Generated #{offset[:direction]} offset from anchorage #{location.id}"
          )
          
          # Copy the classification from the original location
          new_location.classifications.create!(
            classifier_type: 'human',
            is_result: true,
            notes: "Inherited from anchorage #{location.id} (#{meters}m #{offset[:direction]} offset)"
          )
          
          success += 1
        end
        
      rescue => e
        errors += 1
        puts "\nError processing location #{location.id}: #{e.message}"
      end
    end
    
    puts "\n\nPoint generation complete!"
    puts "Successfully created: #{success} offset points"
    puts "Errors: #{errors}"
    puts "\nYou can now run 'rake ml:refetch_anchorage_images' to fetch images for all points"
  end

  desc "Remove generated offset points"
  task :remove_offset_points => :environment do
    # Find all locations with source starting with 'offset_'
    locations = Location.where("source LIKE 'offset_%'")
    total = locations.count
    
    if total.zero?
      puts "No offset points found"
      return
    end
    
    puts "\nFound #{total} offset points"
    puts "Starting cleanup..."
    
    success = 0
    errors = 0
    
    locations.find_each.with_index do |location, index|
      print "\rProcessing #{index + 1}/#{total} (#{((index + 1).to_f / total * 100).round(1)}%)"
      
      begin
        # Remove the image if it exists
        location.satellite_image.purge if location.satellite_image.attached?
        # Delete the location and its classifications (will cascade)
        location.destroy
        success += 1
      rescue => e
        errors += 1
        puts "\nError removing location #{location.id}: #{e.message}"
      end
    end
    
    puts "\n\nCleanup complete!"
    puts "Successfully removed: #{success} offset points"
    puts "Errors: #{errors}"
  end

  desc "Fetch images for offset points only"
  task fetch_offset_images: :environment do
    require 'mini_magick'

    # Get all offset points without images
    locations = Location.where("source LIKE 'offset_%'")
                      .where(fetched_at: nil)
    total = locations.count
    
    if total.zero?
      puts "No offset points found needing images"
      return
    end
    
    puts "\nFound #{total} offset points needing images"
    puts "Starting high-quality image fetch..."
    puts "This will:"
    puts "1. Fetch images at 448x448 (scale=2)"
    puts "2. Store in PNG format"
    puts "3. Apply Lanczos downsampling to 224x224"
    puts "\nProgress:"
    
    success = 0
    errors = 0
    
    locations.find_each.with_index do |location, index|
      print "\rProcessing #{index + 1}/#{total} (#{((index + 1).to_f / total * 100).round(1)}%)"
      
      begin
        # Fetch high-res image
        service = GoogleMapsService.new
        image_data = service.fetch_static_map(
          latitude: location.latitude,
          longitude: location.longitude,
          size: "224x224",
          scale: 2
        )
        
        # Process with high quality settings
        image = MiniMagick::Image.read(image_data)
        image.format 'png'
        image.combine_options do |c|
          c.resize "224x224"
          c.filter "Lanczos"
          c.quality "100"
        end
        
        # Prepare processed image for attachment
        processed_image = StringIO.new
        processed_image.write(image.to_blob)
        processed_image.rewind
        
        # Attach new image
        location.satellite_image.attach(
          io: processed_image,
          filename: "satellite_#{location.id}.png",
          content_type: "image/png"
        )
        
        location.update(fetched_at: Time.current)
        success += 1
        
      rescue => e
        errors += 1
        puts "\nError processing location #{location.id}: #{e.message}"
      end
      
      # Add a small delay to respect rate limits
      sleep(0.1)
    end
    
    puts "\n\nProcess complete!"
    puts "Successfully processed: #{success}"
    puts "Errors: #{errors}"
    puts "\nAll done! 🎉"
  end

  desc "Fix missing classifications for offset points"
  task fix_offset_classifications: :environment do
    # Find all offset points without classifications
    locations = Location.where("source LIKE 'offset_%'")
                      .left_joins(:classifications)
                      .where(classifications: { id: nil })
    total = locations.count
    
    if total.zero?
      puts "No offset points found with missing classifications"
      return
    end
    
    puts "\nFound #{total} offset points with missing classifications"
    puts "Adding positive classifications..."
    
    success = 0
    errors = 0
    
    locations.find_each.with_index do |location, index|
      print "\rProcessing #{index + 1}/#{total} (#{((index + 1).to_f / total * 100).round(1)}%)"
      
      begin
        # Extract original location ID from source
        if match = location.source.match(/offset_\w+_\d+m_from_(\d+)/)
          original_id = match[1]
          
          # Create positive classification
          location.classifications.create!(
            classifier_type: 'human',
            is_result: true,
            notes: "Inherited from anchorage #{original_id} (automatically fixed)"
          )
          
          success += 1
        else
          puts "\nError: Could not parse source format for location #{location.id}"
          errors += 1
        end
      rescue => e
        errors += 1
        puts "\nError processing location #{location.id}: #{e.message}"
      end
    end
    
    puts "\n\nClassification fix complete!"
    puts "Successfully processed: #{success}"
    puts "Errors: #{errors}"
    puts "\nAll done! 🎉"
  end

  desc "Fetch images for human-classified non-anchorages"
  task fetch_non_anchorage_images: :environment do
    require 'mini_magick'

    # Get all human-classified non-anchorages without images
    locations = Location.joins(:classifications)
                      .where(classifications: { classifier_type: 'human', is_result: false })
                      .where("classifications.created_at = (
                        SELECT MAX(c2.created_at)
                        FROM classifications c2
                        WHERE c2.location_id = locations.id
                        AND c2.classifier_type = 'human'
                      )")
                      .where(fetched_at: nil)
                      .distinct
    total = locations.count
    
    if total.zero?
      puts "No non-anchorage points found needing images"
      return
    end
    
    puts "\nFound #{total} non-anchorage points needing images"
    puts "Starting high-quality image fetch..."
    puts "This will:"
    puts "1. Fetch images at 448x448 (scale=2)"
    puts "2. Store in PNG format"
    puts "3. Apply Lanczos downsampling to 224x224"
    puts "\nProgress:"
    
    success = 0
    errors = 0
    
    locations.find_each.with_index do |location, index|
      print "\rProcessing #{index + 1}/#{total} (#{((index + 1).to_f / total * 100).round(1)}%)"
      
      begin
        # Fetch high-res image
        service = GoogleMapsService.new
        image_data = service.fetch_static_map(
          latitude: location.latitude,
          longitude: location.longitude,
          size: "224x224",
          scale: 2
        )
        
        # Process with high quality settings
        image = MiniMagick::Image.read(image_data)
        image.format 'png'
        image.combine_options do |c|
          c.resize "224x224"
          c.filter "Lanczos"
          c.quality "100"
        end
        
        # Prepare processed image for attachment
        processed_image = StringIO.new
        processed_image.write(image.to_blob)
        processed_image.rewind
        
        # Attach new image
        location.satellite_image.attach(
          io: processed_image,
          filename: "satellite_#{location.id}.png",
          content_type: "image/png"
        )
        
        location.update(fetched_at: Time.current)
        success += 1
        
      rescue => e
        errors += 1
        puts "\nError processing location #{location.id}: #{e.message}"
      end
      
      # Add a small delay to respect rate limits
      sleep(0.1)
    end
    
    puts "\n\nProcess complete!"
    puts "Successfully processed: #{success}"
    puts "Errors: #{errors}"
    puts "\nAll done! 🎉"
  end

  desc "Reclassify all locations that have satellite images"
  task reclassify_all: :environment do
    BATCH_SIZE = 5  # Process 5 locations at a time
    
    # Get all locations with satellite images
    scope = Location.joins(:satellite_image_attachment).distinct
    total = scope.count
    
    puts "\nFound #{total} locations with satellite images to classify"
    puts "Starting classification with new model..."
    
    # Start the Node.js model server
    unless Ml::ClassifierService.start_server
      puts "Failed to start model server. Please check the logs in log/image_classification_service.log"
      exit 1
    end
    
    puts "Model server is ready!"
    
    success = 0
    errors = 0
    
    # Process in batches
    scope.find_each.each_slice(BATCH_SIZE) do |locations_batch|
      threads = locations_batch.map do |location|
        Thread.new do
          if Ml::ClassifierService.classify_location(location)
            Thread.current[:success] = true
          else
            Thread.current[:error] = true
          end
        end
      end

      # Wait for all threads to complete
      threads.each do |thread|
        thread.join
        if thread[:success]
          success += 1
        elsif thread[:error]
          errors += 1
        end
      end
      
      # Print progress
      progress = ((success + errors).to_f / total * 100).round(1)
      print "\rProgress: #{progress}% (#{success + errors}/#{total} locations processed)"
    end
    
    puts "\n\nClassification complete!"
    puts "Successfully classified: #{success}"
    puts "Errors: #{errors}"
  end
end 