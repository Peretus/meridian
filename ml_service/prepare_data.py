import os
import shutil
from pathlib import Path
import random

def create_data_structure():
    """Create the required directory structure."""
    base_dir = Path("data")
    train_dir = base_dir / "train"
    validation_dir = base_dir / "validation"
    
    # Create main directories
    train_dir.mkdir(parents=True, exist_ok=True)
    validation_dir.mkdir(parents=True, exist_ok=True)
    
    return base_dir, train_dir, validation_dir

def split_data(source_dir, train_dir, validation_dir, split_ratio=0.8):
    """Split images into training and validation sets."""
    source_path = Path(source_dir)
    
    # Get all image files (adjust extensions as needed)
    image_files = []
    for ext in ['.jpg', '.jpeg', '.png']:
        image_files.extend(source_path.glob(f'**/*{ext}'))
    
    # Group files by their parent directory (class)
    files_by_class = {}
    for img_path in image_files:
        class_name = img_path.parent.name
        if class_name not in files_by_class:
            files_by_class[class_name] = []
        files_by_class[class_name].append(img_path)
    
    # Create class directories and split files
    for class_name, files in files_by_class.items():
        # Create directories
        (train_dir / class_name).mkdir(exist_ok=True)
        (validation_dir / class_name).mkdir(exist_ok=True)
        
        # Shuffle files
        random.shuffle(files)
        
        # Split point
        split_point = int(len(files) * split_ratio)
        
        # Copy files to train directory
        for file_path in files[:split_point]:
            shutil.copy2(file_path, train_dir / class_name / file_path.name)
        
        # Copy files to validation directory
        for file_path in files[split_point:]:
            shutil.copy2(file_path, validation_dir / class_name / file_path.name)
        
        print(f"Class {class_name}:")
        print(f"  Training: {split_point} images")
        print(f"  Validation: {len(files) - split_point} images")

if __name__ == "__main__":
    # Create directory structure
    base_dir, train_dir, validation_dir = create_data_structure()
    
    # Use default source directory
    source_dir = "data/source"
    
    if not os.path.exists(source_dir):
        print(f"Error: Source directory {source_dir} does not exist!")
        exit(1)
    
    # Use default split ratio
    split_ratio = 0.8
    print(f"\nUsing split ratio: {split_ratio * 100}% training, {(1 - split_ratio) * 100}% validation")
    
    # Process the data
    print("\nPreparing data...")
    split_data(source_dir, train_dir, validation_dir, split_ratio)
    
    print("\nData preparation complete!")
    print(f"Training data in: {train_dir}")
    print(f"Validation data in: {validation_dir}")
    print("\nYou can now run train.py to train your model!") 