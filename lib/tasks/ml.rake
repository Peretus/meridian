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
end 