"""
NOTE: This script is intended to be run through the Rails rake task:
    rails ml:retrain

The rake task pipeline:
1. ml:export_training_data - Exports classified images from the database
2. ml:prepare_data - Splits data into train/validation sets
3. ml:train - Runs this training script

Do not run this script directly with Python. The rake tasks handle all the
necessary data preparation and directory structure setup.

IMPORTANT: For devs that may come later: Don't update this model without checking with Casey.
"""

import tensorflow as tf
from tensorflow.keras import layers, models, callbacks
from tensorflow.keras.preprocessing.image import ImageDataGenerator
import os
import json
from datetime import datetime

# Configuration
IMG_SIZE = 224
BATCH_SIZE = 32
EPOCHS = 10
CHECKPOINT_DIR = 'models/classifier/checkpoints'

def create_model():
    """Create a robust CNN model for binary classification of anchorages.
    
    Architecture features:
    - Deeper network with residual connections
    - Batch normalization for better training
    - Multiple dropout layers to prevent overfitting
    - Gradually increasing filters in conv layers
    """
    inputs = layers.Input(shape=(IMG_SIZE, IMG_SIZE, 3))
    
    # Initial convolution block
    x = layers.Conv2D(32, 3, padding='same')(inputs)
    x = layers.BatchNormalization()(x)
    x = layers.Activation('relu')(x)
    x = layers.MaxPooling2D()(x)
    
    # First residual block
    residual = x
    x = layers.Conv2D(64, 3, padding='same')(x)
    x = layers.BatchNormalization()(x)
    x = layers.Activation('relu')(x)
    x = layers.Conv2D(64, 3, padding='same')(x)
    x = layers.BatchNormalization()(x)
    residual = layers.Conv2D(64, 1)(residual)  # 1x1 conv to match dimensions
    x = layers.Add()([x, residual])
    x = layers.Activation('relu')(x)
    x = layers.MaxPooling2D()(x)
    x = layers.Dropout(0.25)(x)
    
    # Second residual block
    residual = x
    x = layers.Conv2D(128, 3, padding='same')(x)
    x = layers.BatchNormalization()(x)
    x = layers.Activation('relu')(x)
    x = layers.Conv2D(128, 3, padding='same')(x)
    x = layers.BatchNormalization()(x)
    residual = layers.Conv2D(128, 1)(residual)  # 1x1 conv to match dimensions
    x = layers.Add()([x, residual])
    x = layers.Activation('relu')(x)
    x = layers.MaxPooling2D()(x)
    x = layers.Dropout(0.25)(x)
    
    # Third residual block
    residual = x
    x = layers.Conv2D(256, 3, padding='same')(x)
    x = layers.BatchNormalization()(x)
    x = layers.Activation('relu')(x)
    x = layers.Conv2D(256, 3, padding='same')(x)
    x = layers.BatchNormalization()(x)
    residual = layers.Conv2D(256, 1)(residual)  # 1x1 conv to match dimensions
    x = layers.Add()([x, residual])
    x = layers.Activation('relu')(x)
    x = layers.MaxPooling2D()(x)
    x = layers.Dropout(0.25)(x)
    
    # Classification head
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dense(512, activation='relu')(x)
    x = layers.BatchNormalization()(x)
    x = layers.Dropout(0.5)(x)
    x = layers.Dense(256, activation='relu')(x)
    x = layers.BatchNormalization()(x)
    x = layers.Dropout(0.5)(x)
    outputs = layers.Dense(1, activation='sigmoid')(x)
    
    model = models.Model(inputs=inputs, outputs=outputs)
    return model

def create_callbacks(checkpoint_dir):
    """Create callbacks for monitoring and model checkpointing."""
    os.makedirs(checkpoint_dir, exist_ok=True)
    
    # Model checkpoint to save best model
    checkpoint_path = os.path.join(checkpoint_dir, 'model_{epoch:02d}_{val_accuracy:.4f}.keras')
    checkpoint = callbacks.ModelCheckpoint(
        checkpoint_path,
        monitor='val_accuracy',
        save_best_only=True,
        mode='max',
        verbose=1
    )
    
    # Early stopping to prevent overfitting
    early_stopping = callbacks.EarlyStopping(
        monitor='val_accuracy',
        patience=5,
        restore_best_weights=True,
        verbose=1
    )
    
    # CSV logger for detailed metrics
    csv_logger = callbacks.CSVLogger(
        os.path.join(checkpoint_dir, f'training_log_{datetime.now().strftime("%Y%m%d_%H%M%S")}.csv')
    )
    
    # Reduce learning rate when plateauing
    reduce_lr = callbacks.ReduceLROnPlateau(
        monitor='val_loss',
        factor=0.5,
        patience=3,
        verbose=1
    )
    
    return [checkpoint, early_stopping, csv_logger, reduce_lr]

def train_model(train_dir, validation_dir):
    """Train the model on the provided data."""
    
    # Data augmentation for training (as specified in ml_training_plan.md)
    train_datagen = ImageDataGenerator(
        rescale=1./255,
        rotation_range=360,     # full rotation for orientation invariance
        width_shift_range=0.3,  
        height_shift_range=0.3,
        shear_range=0.3,       
        zoom_range=0.3,        
        horizontal_flip=True,
        vertical_flip=True,     # anchorages can look similar upside down
        brightness_range=[0.7, 1.3],  # moderate brightness variation
        fill_mode='nearest'
    )

    # Only rescaling for validation
    validation_datagen = ImageDataGenerator(rescale=1./255)

    # Create data generators with binary mode
    train_generator = train_datagen.flow_from_directory(
        train_dir,
        target_size=(IMG_SIZE, IMG_SIZE),
        batch_size=BATCH_SIZE,
        class_mode='binary',  # Binary classification
        classes=['not_anchorage', 'anchorage'],  # Order matters for binary: 0=not_anchorage, 1=anchorage
        shuffle=True,
        seed=42
    )

    validation_generator = validation_datagen.flow_from_directory(
        validation_dir,
        target_size=(IMG_SIZE, IMG_SIZE),
        batch_size=BATCH_SIZE,
        class_mode='binary',  # Binary classification
        classes=['not_anchorage', 'anchorage'],  # Same order as training
        shuffle=False,
        seed=42
    )

    # Create and compile model
    model = create_model()
    
    # Convert generators to tf.data.Dataset
    train_dataset = tf.data.Dataset.from_generator(
        lambda: train_generator,
        output_signature=(
            tf.TensorSpec(shape=(None, IMG_SIZE, IMG_SIZE, 3), dtype=tf.float32),
            tf.TensorSpec(shape=(None,), dtype=tf.float32)
        )
    )
    
    validation_dataset = tf.data.Dataset.from_generator(
        lambda: validation_generator,
        output_signature=(
            tf.TensorSpec(shape=(None, IMG_SIZE, IMG_SIZE, 3), dtype=tf.float32),
            tf.TensorSpec(shape=(None,), dtype=tf.float32)
        )
    )
    
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
        loss='binary_crossentropy',
        metrics=[
            'accuracy',
            tf.keras.metrics.Precision(name='precision'),
            tf.keras.metrics.Recall(name='recall'),
            tf.keras.metrics.AUC(name='auc')
        ]
    )

    # Train the model using datasets
    history = model.fit(
        train_dataset,
        steps_per_epoch=train_generator.samples // BATCH_SIZE,
        epochs=EPOCHS,
        validation_data=validation_dataset,
        validation_steps=validation_generator.samples // BATCH_SIZE,
        callbacks=create_callbacks(CHECKPOINT_DIR),
        class_weight={0: 1.0, 1: 15.0}  # Add back class weights as specified in training plan
    )

    return model, history, train_generator.class_indices

def save_model_and_labels(model, class_indices, history, output_dir='models/classifier'):
    """Save the model, class labels, and training history."""
    os.makedirs(output_dir, exist_ok=True)
    
    # Save model
    model.save(os.path.join(output_dir, 'model.keras'))
    
    # Save class labels
    with open(os.path.join(output_dir, 'labels.txt'), 'w') as f:
        for class_name, index in sorted(class_indices.items(), key=lambda x: x[1]):
            f.write(f"{index} {class_name}\n")
    
    # Save training history
    with open(os.path.join(output_dir, 'training_history.json'), 'w') as f:
        history_dict = {key: [float(val) for val in values] for key, values in history.history.items()}
        json.dump(history_dict, f, indent=2)

if __name__ == "__main__":
    # Paths to your data
    train_dir = "data/train"
    validation_dir = "data/validation"
    
    # Check if data directories exist
    if not os.path.exists(train_dir) or not os.path.exists(validation_dir):
        print(f"Please create the following directory structure:")
        print(f"data/")
        print(f"├── train/")
        print(f"│   ├── anchorage/")
        print(f"│   └── not_anchorage/")
        print(f"└── validation/")
        print(f"    ├── anchorage/")
        print(f"    └── not_anchorage/")
        exit(1)
    
    # Validate binary classification structure
    train_classes = os.listdir(train_dir)
    val_classes = os.listdir(validation_dir)
    expected_classes = {'anchorage', 'not_anchorage'}
    
    if set(train_classes) != expected_classes or set(val_classes) != expected_classes:
        print("Error: Data directory structure is incorrect.")
        print("Expected exactly two classes: 'anchorage' and 'not_anchorage'")
        print(f"Found in train: {train_classes}")
        print(f"Found in validation: {val_classes}")
        exit(1)
    
    # Train the model
    print("Starting training...")
    model, history, class_indices = train_model(train_dir, validation_dir)
    
    # Save the model, labels, and history
    print("\nSaving model, labels, and training history...")
    save_model_and_labels(model, class_indices, history)
    
    print("\nTraining complete! Model and labels saved in models/classifier/")
    print("\nFinal metrics:")
    print(f"Training accuracy: {history.history['accuracy'][-1]:.2%}")
    print(f"Validation accuracy: {history.history['val_accuracy'][-1]:.2%}")
    print(f"Precision: {history.history['precision'][-1]:.2%}")
    print(f"Recall: {history.history['recall'][-1]:.2%}")
    print(f"AUC: {history.history['auc'][-1]:.2%}") 