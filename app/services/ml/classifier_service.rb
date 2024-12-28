require 'httparty'
require 'base64'

module Ml
  class ClassifierService
    BATCH_SIZE = 5  # Process 5 locations at a time
    MODEL_SERVER_URL = 'http://localhost:3001'
    MAX_RETRIES = 5
    RETRY_DELAY = 2 # seconds

    class << self
      def ensure_server_running
        retries = 0
        begin
          response = HTTParty.get("#{MODEL_SERVER_URL}/health", timeout: 5)
          return true if response.success?
        rescue => e
          if retries < MAX_RETRIES
            retries += 1
            Rails.logger.info "Waiting for server to start (attempt #{retries}/#{MAX_RETRIES})..."
            sleep RETRY_DELAY
            retry
          end
          Rails.logger.error "Failed to connect to model server: #{e.message}"
          return false
        end
        false
      end

      def start_server
        Rails.logger.info "Starting Node.js model server..."
        node_service_path = Rails.root.join('node_service')
        
        # Check if server is already running
        return true if ensure_server_running

        begin
          # Start the server in the background
          pid = spawn(
            { 'NODE_ENV' => Rails.env },
            'npm start',
            chdir: node_service_path.to_s,
            out: Rails.root.join('log/node_service.log').to_s,
            err: Rails.root.join('log/node_service.error.log').to_s
          )
          Process.detach(pid)
          
          # Wait for server to be ready
          sleep 2 # Initial wait for process to start
          ensure_server_running
        rescue => e
          Rails.logger.error "Failed to start model server: #{e.message}"
          false
        end
      end

      def classify_location(location)
        return false unless location.satellite_image.attached?

        begin
          # Read the image and convert to base64
          Rails.logger.info "Processing location #{location.id}..."
          image_path = ActiveStorage::Blob.service.path_for(location.satellite_image.key)
          Rails.logger.info "Reading image from path: #{image_path}"
          
          image_data = Base64.strict_encode64(File.read(image_path))
          Rails.logger.info "Successfully converted image to base64"

          # Call the Node.js model server directly
          Rails.logger.info "Making request to model server..."
          response = HTTParty.post(
            "#{MODEL_SERVER_URL}/predict",
            headers: { 'Content-Type' => 'application/json' },
            body: { image: image_data }.to_json,
            timeout: 10
          )

          Rails.logger.info "Got response with status: #{response.code}"
          Rails.logger.info "Response body: #{response.body}"

          if response.success?
            result = JSON.parse(response.body)
            probabilities = result['predictions']
            
            Rails.logger.info "Parsed predictions: #{probabilities.inspect}"
            
            # Get class probabilities (assuming binary classification)
            is_result = probabilities[0] >= 0.5  # First class is 'result'
            confidence = is_result ? probabilities[0] : probabilities[1]
            
            # Create a new classification
            classification = location.classifications.create!(
              classifier_type: 'machine',
              is_result: is_result,
              model_version: 'teachable_machine_v1'
            )
            
            Rails.logger.info "Created classification #{classification.id} for location #{location.id} as #{is_result ? 'result' : 'non-result'} with confidence #{confidence}"
            true
          else
            Rails.logger.error "Failed to classify location #{location.id}"
            Rails.logger.error "Response code: #{response.code}"
            Rails.logger.error "Response body: #{response.body}"
            false
          end
        rescue => e
          Rails.logger.error "Error classifying location #{location.id}: #{e.message}"
          Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
          false
        end
      end

      def classify_unclassified_locations
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
        
        # Process in batches of BATCH_SIZE
        scope.find_each.each_slice(BATCH_SIZE) do |locations_batch|
          threads = locations_batch.map do |location|
            Thread.new do
              if classify_location(location)
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

      def test_image_processing(location)
        return false unless location.satellite_image.attached?

        begin
          # Read the image and convert to base64
          Rails.logger.info "Testing image processing for location #{location.id}..."
          image_path = ActiveStorage::Blob.service.path_for(location.satellite_image.key)
          Rails.logger.info "Reading image from path: #{image_path}"
          
          image_data = Base64.strict_encode64(File.read(image_path))
          Rails.logger.info "Successfully converted image to base64"

          # Call the test endpoint
          Rails.logger.info "Making request to test endpoint..."
          response = HTTParty.post(
            "#{MODEL_SERVER_URL}/test-image",
            headers: { 'Content-Type' => 'application/json' },
            body: { image: image_data }.to_json,
            timeout: 10
          )

          Rails.logger.info "Got response with status: #{response.code}"
          Rails.logger.info "Response body: #{response.body}"

          response.success?
        rescue => e
          Rails.logger.error "Error testing image: #{e.message}"
          Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
          false
        end
      end
    end
  end
end 