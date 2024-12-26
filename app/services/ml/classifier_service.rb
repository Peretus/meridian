require 'httparty'

module Ml
  class ClassifierService
    def self.classify_location(location)
      return false unless location.satellite_image.attached?

      # Call the ML service
      response = HTTParty.post(
        'http://localhost:8000/classify',
        multipart: true,
        body: {
          file: File.open(ActiveStorage::Blob.service.path_for(location.satellite_image.key))
        }
      )

      if response.success?
        result = JSON.parse(response.body)
        
        # Create a new classification
        location.classifications.create!(
          classifier_type: 'machine',
          is_result: result['class'] == 'anchorage',
          model_version: '1.0' # We can update this later with actual versioning
        )
        
        Rails.logger.info "Classified location #{location.id} as #{result['class']} with confidence #{result['confidence']}"
        true
      else
        Rails.logger.error "Failed to classify location #{location.id}: #{response.body}"
        false
      end
    rescue => e
      Rails.logger.error "Error classifying location #{location.id}: #{e.message}"
      false
    end

    def self.classify_unclassified_locations
      # Get locations with satellite images but no classifications
      scope = Location
        .joins(:satellite_image_attachment)
        .left_joins(:classifications)
        .where(classifications: { id: nil })
        .distinct
      
      total = scope.count
      return if total.zero?
      
      puts "Found #{total} unclassified locations with satellite images. Starting classification..."
      
      success = 0
      errors = 0
      
      scope.find_each.with_index do |location, index|
        if classify_location(location)
          success += 1
        else
          errors += 1
        end
        
        # Print progress
        progress = ((index + 1).to_f / total * 100).round(1)
        print "\rProgress: #{progress}% (#{index + 1}/#{total} locations processed)"
      end
      
      puts "\n\nClassification complete!"
      puts "Successfully classified: #{success}"
      puts "Errors: #{errors}"
    end
  end
end 