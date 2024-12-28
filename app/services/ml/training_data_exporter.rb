module Ml
  class TrainingDataExporter
    ML_SERVICE_PATH = Rails.root.join('ml_service')
    SOURCE_PATH = ML_SERVICE_PATH.join('data', 'source')
    
    def self.export_classified_images
      # Clean up old exports
      cleanup_old_exports
      
      # Get all locations with human classifications
      total_locations = Location.with_human_classifications.count
      if total_locations.zero?
        puts "No human-classified locations found. Please classify some locations first."
        return false
      end
      
      puts "Found #{total_locations} human-classified locations. Starting export..."
      
      # Track statistics
      stats = Hash.new(0)
      errors = []
      
      Location.with_human_classifications.find_each.with_index do |location, index|
        classification = location.classification_for_training
        next unless classification # Skip if no valid classification
        
        class_dir = SOURCE_PATH.join(classification)
        FileUtils.mkdir_p(class_dir)
        
        # Export satellite image if it exists
        if location.satellite_image.attached?
          # Create a unique filename
          filename = "#{location.id}_satellite.png"
          target_path = class_dir.join(filename)
          
          # Download and save the image
          begin
            File.open(target_path, 'wb') do |file|
              file.write(location.satellite_image.download)
            end
            stats[classification] += 1
            Rails.logger.info "Exported #{filename} to #{classification} class"
          rescue => e
            error_msg = "Failed to export #{filename}: #{e.message}"
            Rails.logger.error error_msg
            errors << error_msg
          end
        else
          Rails.logger.warn "Location #{location.id} has no satellite image attached"
        end
        
        # Print progress
        print_progress(index + 1, total_locations)
      end
      
      # Print final statistics
      print_final_stats(stats, errors)
      
      # Return success status
      errors.empty? && stats.values.sum > 0
    end
    
    def self.print_progress(current, total)
      progress = (current.to_f / total * 100).round(1)
      print "\rProgress: #{progress}% (#{current}/#{total} locations processed)"
    end
    
    def self.print_final_stats(stats, errors)
      puts "\n\nExport Statistics:"
      stats.each do |classification, count|
        puts "#{classification}: #{count} images"
      end
      
      if errors.any?
        puts "\nErrors encountered:"
        errors.each { |error| puts "- #{error}" }
      end
      
      total_images = stats.values.sum
      puts "\nTotal images exported: #{total_images}"
      puts "Total errors: #{errors.count}"
      
      if total_images > 0
        puts "\nClass distribution:"
        stats.each do |classification, count|
          percentage = (count.to_f / total_images * 100).round(1)
          puts "#{classification}: #{percentage}%"
        end
      end
    end
    
    def self.cleanup_old_exports
      if Dir.exist?(SOURCE_PATH)
        puts "Cleaning up old exports..."
        FileUtils.rm_rf(SOURCE_PATH)
      end
      FileUtils.mkdir_p(SOURCE_PATH)
    end
  end
end 