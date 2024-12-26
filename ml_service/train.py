import tensorflow as tf
from tensorflow.keras import layers, models
from tensorflow.keras.preprocessing.image import ImageDataGenerator
import os

# Configuration
IMG_SIZE = 224
BATCH_SIZE = 32
EPOCHS = 10

def create_model(num_classes):
    """Create a simple but effective CNN model."""
    model = models.Sequential([
        # Base
        layers.Conv2D(32, 3, activation='relu', input_shape=(IMG_SIZE, IMG_SIZE, 3)),
        layers.MaxPooling2D(),
        layers.Conv2D(64, 3, activation='relu'),
        layers.MaxPooling2D(),
        layers.Conv2D(64, 3, activation='relu'),
        layers.MaxPooling2D(),
        
        # Classification head
        layers.Flatten(),
        layers.Dense(64, activation='relu'),
        layers.Dropout(0.5),
        layers.Dense(num_classes, activation='softmax')
    ])
    
    return model

def train_model(train_dir, validation_dir):
    """Train the model on the provided data."""
    
    # Data augmentation for training
    train_datagen = ImageDataGenerator(
        rescale=1./255,
        rotation_range=20,
        width_shift_range=0.2,
        height_shift_range=0.2,
        shear_range=0.2,
        zoom_range=0.2,
        horizontal_flip=True,
        fill_mode='nearest'
    )

    # Only rescaling for validation
    validation_datagen = ImageDataGenerator(rescale=1./255)

    # Create data generators
    train_generator = train_datagen.flow_from_directory(
        train_dir,
        target_size=(IMG_SIZE, IMG_SIZE),
        batch_size=BATCH_SIZE,
        class_mode='categorical'
    )

    validation_generator = validation_datagen.flow_from_directory(
        validation_dir,
        target_size=(IMG_SIZE, IMG_SIZE),
        batch_size=BATCH_SIZE,
        class_mode='categorical'
    )

    # Create and compile model
    num_classes = len(train_generator.class_indices)
    model = create_model(num_classes)
    
    model.compile(
        optimizer='adam',
        loss='categorical_crossentropy',
        metrics=['accuracy']
    )

    # Train the model
    history = model.fit(
        train_generator,
        steps_per_epoch=train_generator.samples // BATCH_SIZE,
        epochs=EPOCHS,
        validation_data=validation_generator,
        validation_steps=validation_generator.samples // BATCH_SIZE
    )

    return model, history, train_generator.class_indices

def save_model_and_labels(model, class_indices, output_dir='models/classifier'):
    """Save the model and class labels."""
    os.makedirs(output_dir, exist_ok=True)
    
    # Save model
    model.save(os.path.join(output_dir, 'model.h5'))
    
    # Save class labels
    with open(os.path.join(output_dir, 'labels.txt'), 'w') as f:
        for class_name, index in sorted(class_indices.items(), key=lambda x: x[1]):
            f.write(f"{index} {class_name}\n")

if __name__ == "__main__":
    # Paths to your data
    train_dir = "data/train"
    validation_dir = "data/validation"
    
    # Check if data directories exist
    if not os.path.exists(train_dir) or not os.path.exists(validation_dir):
        print(f"Please create the following directory structure:")
        print(f"data/")
        print(f"├── train/")
        print(f"│   ├── class1/")
        print(f"│   ├── class2/")
        print(f"│   └── class3/")
        print(f"└── validation/")
        print(f"    ├── class1/")
        print(f"    ├── class2/")
        print(f"    └── class3/")
        exit(1)
    
    # Train the model
    print("Starting training...")
    model, history, class_indices = train_model(train_dir, validation_dir)
    
    # Save the model and labels
    print("\nSaving model and labels...")
    save_model_and_labels(model, class_indices)
    
    print("\nTraining complete! Model and labels saved in models/classifier/")
    print(f"Final training accuracy: {history.history['accuracy'][-1]:.2%}")
    print(f"Final validation accuracy: {history.history['val_accuracy'][-1]:.2%}") 