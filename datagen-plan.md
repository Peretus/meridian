# Data Generation Enhancement Plan

## Progress Log

### Current Step (2024-01-09)
Testing image quality improvement with scale parameter:
- Created test script to compare scale=1 vs scale=2 images
- Used known, human-classified anchorages as test cases
- Implemented PNG format and Lanczos downsampling
- Results:
  - Confirmed significant quality improvement with scale=2 + downsampling
  - PNG format provides better quality than JPEG
  - Lanczos filter produces superior downsampling results

### Next Step
Implementing high-quality image pipeline:
1. Update all image fetching to use PNG format ✓
2. Implement scale=2 fetching with Lanczos downsampling
3. Update existing images to new format

## Overview
This plan outlines the approach to enhance our training dataset by generating higher resolution satellite imagery of known anchorages. Instead of generating new locations, we'll fetch higher quality images of existing locations using:
- PNG format instead of JPEG
- Scale=2 parameter for higher resolution
- Lanczos downsampling for optimal quality

## Current State
- Training data comes from manually validated anchorage locations
- Each location has a single satellite image at 224x224 pixels (scale=1)
- Currently using JPEG format (to be updated to PNG)
- Fixed requirements:
  - 224x224 pixel output size for model
  - Fixed zoom level for model consistency

## Target Features

### 1. High Resolution Image Pipeline
- Fetch images with scale=2 parameter:
  - API fetches 448x448 pixel images in PNG format
  - Downsample to 224x224 using Lanczos filter
  - Results in higher quality, more detailed training data
- Maintain exact same locations and zoom levels
- Track original vs processed image relationships

## Implementation Phases

### Phase 1: Format Migration
1. Update `GoogleMapsService` to use PNG format ✓
2. Update `Location` model to store PNGs ✓
3. Add high-quality downsampling pipeline
4. Create migration task for existing images

### Phase 2: Image Management
1. Track image metadata:
   - Original scale
   - Processing parameters (filter, quality)
   - Format and processing history
2. Store both original and processed versions
3. Implement cleanup/pruning capabilities

### Phase 3: Batch Processing
1. Create rake task for refetching existing images
2. Add validation to ensure quality improvement
3. Implement rate limiting and error handling

### Phase 4: Integration
1. Update training pipeline to use enhanced images
2. Add filtering options for image quality
3. Implement validation metrics

## Technical Considerations

### Data Storage
- Store images in PNG format for better quality
- Track image metadata including processing parameters
- Maintain processing history

### API Usage
- Use scale=2 for higher resolution fetching
- Use PNG format for better quality
- Implement Lanczos downsampling to 224x224
- Cache results to prevent duplicate fetches
- Monitor API quotas and costs

### Validation
- Compare image quality before/after
- Verify model performance with enhanced images
- Track success rates of high-res fetches

## Success Metrics
1. Improved image quality metrics
2. Better model performance on fine details
3. Successful downsampling without artifacts

## Risks & Mitigation
1. API Limitations
   - Monitor quota usage with larger images
   - Implement proper rate limiting
   - Cache aggressively to minimize API calls

2. Storage Impact
   - Track storage usage increase (PNGs are larger)
   - Implement cleanup for original high-res versions
   - Consider compression options if needed

3. Processing Requirements
   - Optimize downsampling process
   - Monitor processing time and resources
   - Consider batch processing strategies

## Next Steps
1. Create migration task for existing images
2. Implement high-quality downsampling pipeline
3. Update training pipeline to use new images 