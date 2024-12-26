namespace :ml do
  desc "Export classified images for ML training"
  task export_training_data: :environment do
    puts "Exporting classified images for ML training..."
    unless Ml::TrainingDataExporter.export_classified_images
      puts "Failed to export training data. Check the logs for details."
      exit 1
    end
  end

  desc "Prepare training data (split into train/validation sets)"
  task prepare_data: :environment do
    puts "Preparing training data..."
    ml_service_path = Rails.root.join('ml_service')
    
    # Change to ml_service directory
    Dir.chdir(ml_service_path) do
      unless system("python prepare_data.py")
        puts "Failed to prepare data. Check the output above for details."
        exit 1
      end
    end
  end

  desc "Train the model"
  task train: :environment do
    puts "Training model..."
    ml_service_path = Rails.root.join('ml_service')
    
    # Change to ml_service directory
    Dir.chdir(ml_service_path) do
      unless system("python train.py")
        puts "Failed to train model. Check the output above for details."
        exit 1
      end
    end
  end

  desc "Export data, prepare, and train model"
  task retrain: [:export_training_data, :prepare_data, :train] do
    puts "\n✨ Model training pipeline complete! ✨"
    puts "\nSummary:"
    puts "1. Exported classified images"
    puts "2. Split into training/validation sets"
    puts "3. Trained new model"
    puts "\nThe model is ready to use!"
  end

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

    puts "Starting ML classification service..."
    
    # Check if port 8000 is in use
    if system("lsof -i:8000", out: File::NULL, err: File::NULL)
      puts "Port 8000 is already in use. Attempting to free it..."
      system("lsof -ti:8000 | xargs kill -9")
      sleep 2 # Give the system time to free the port
    end
    
    # Ensure the FastAPI service is running
    ml_service_path = Rails.root.join('ml_service')
    fastapi_pid = nil
    
    begin
      # Start the FastAPI service
      fastapi_pid = spawn("cd #{ml_service_path} && python -m uvicorn app.main:app --host 0.0.0.0 --port 8000")
      
      # Give the service a moment to start
      puts "Waiting for service to start..."
      5.times do
        sleep 1
        print "."
        $stdout.flush
      end
      puts "\n"
      
      # Check if the service started successfully
      unless system("curl -s http://localhost:8000/health > /dev/null")
        raise "Failed to start ML service"
      end
      
      puts "ML service is ready!"
      
      # Run the classifier
      Ml::ClassifierService.classify_unclassified_locations
    rescue => e
      puts "Error: #{e.message}"
      exit 1
    ensure
      # Clean up the FastAPI process
      if fastapi_pid
        Process.kill('TERM', fastapi_pid) rescue nil
        Process.wait(fastapi_pid) rescue nil
        puts "ML service stopped."
      end
    end
  end

  desc "Retrain model and classify unclassified locations"
  task retrain_and_classify: [:retrain, :classify] do
    puts "\n🎉 Complete! Model retrained and all unclassified locations processed."
  end

  desc "Fetch missing satellite images for locations"
  task fetch_images: :environment do
    Location.fetch_missing_satellite_images
  end
end 