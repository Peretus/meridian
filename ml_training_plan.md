# ML Training Plan

## Current Challenges
- Significant class imbalance (222 anchorages vs 8,149 non-anchorages)
- Limited number of positive examples
- Need to maintain model generalization while addressing imbalance

## Progress Notes (2024)
### Generator Structure Debug Resolution
1. Initial Issue:
   - Generator yielded elements didn't match expected structure
   - Error: Expected (tf.float32, tf.float32, tf.float32), but got 2 elements instead of 3

2. Resolution Steps:
   a. Simplified metrics to just accuracy initially
   b. Wrapped ImageDataGenerator in tf.data.Dataset with explicit output signatures:
      ```python
      tf.TensorSpec(shape=(None, IMG_SIZE, IMG_SIZE, 3), dtype=tf.float32),  # images
      tf.TensorSpec(shape=(None,), dtype=tf.float32)  # binary labels
      ```
   c. Configured generators for binary mode with explicit class ordering:
      - classes=['not_anchorage', 'anchorage']
      - class_mode='binary'

3. Current Status:
   - Basic training pipeline working
   - Successfully added back metrics (precision, recall, AUC)
   - Restored class weights (1.0 for not_anchorage, 15.0 for anchorage)
   - Initial training observations (Epoch 1):
     * High initial loss (~6.4-7.9) and increasing
     * Accuracy around 52% (slightly decreasing)
     * AUC near 0.50 (close to random)
     * Precision around 0.49
   - Potential concerns:
     * High and increasing loss suggests potential learning rate or architecture issues
     * Near-random AUC might indicate class weight adjustment needed
   - Next monitoring points:
     * Watch for loss decrease in subsequent epochs
     * Monitor precision/recall balance
     * Check if metrics improve after first epoch

4. Next Steps:
   - Continue monitoring training completion
   - If metrics don't improve by epoch 2-3:
     * Consider reducing learning rate
     * May need to adjust class weights
     * Might need to reduce model complexity initially
   - Evaluate final metrics
   - Adjust parameters based on results

## Proposed Solution
Combining two approaches to address class imbalance:
1. Enhanced data augmentation for anchorages
2. Moderate class weighting
3. IMPORTANT: Use binary classification (class_mode='binary')

### Data Augmentation Strategy
```python
anchorage_datagen = ImageDataGenerator(
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
```

### Class Weights
```python
class_weights = {
    0: 1.0,    # non-anchorage
    1: 15.0    # anchorage (moderate weight instead of full 36:1 ratio)
}
```

## Monitoring and Adjustment Strategy
1. Monitor validation accuracy closely during training
2. Watch for signs of overfitting:
   - If validation accuracy drops while training accuracy rises:
     a. First reduce weights
     b. Then reduce augmentation if needed
3. Watch for signs of underfitting:
   - If both accuracies are low:
     a. Increase weights
     b. Consider more aggressive augmentation

## Implementation Steps
1. Backup current human-classified anchorages
2. Implement enhanced data augmentation
3. Add class weights to model training
4. Train model with new parameters
5. Evaluate performance
6. Adjust parameters based on monitoring strategy

## Success Metrics
- Improved validation accuracy
- Better balance between precision and recall
- Reduced false negatives (missed anchorages)
- Maintained or improved false positive rate

## TEMPORARY: Generator Structure Debug Plan
1. Baseline Configuration:
   - Simplify model metrics to just accuracy
   - Verify basic binary classification pipeline works
   - Confirm data generator yields correct structure (2 elements: images and labels)

2. Metrics Integration:
   - Add precision metric with binary mode
   - Add recall metric with binary mode
   - Add AUC metric with binary mode
   - Test each addition separately to isolate issues

3. Data Flow Verification:
   - Confirm prepare_data.py creates correct structure
   - Verify ImageDataGenerator configuration matches model expectations
   - Ensure class weights format aligns with binary mode

4. Final Integration:
   - Combine working components
   - Verify full pipeline with all metrics
   - Remove this debug section once confirmed working

Note: This section will be removed once the generator structure issue is resolved. 