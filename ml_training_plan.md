# ML Training Plan

## Current Challenges
- Significant class imbalance (222 anchorages vs 8,149 non-anchorages)
- Limited number of positive examples
- Need to maintain model generalization while addressing imbalance

## Proposed Solution
Combining two approaches to address class imbalance:
1. Enhanced data augmentation for anchorages
2. Moderate class weighting

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