# Migration Plan: FastAPI/TensorFlow to Node.js/TensorFlow.js

## Current Architecture
- Rails application (main app)
  - Uses `Ml::ClassifierService` for ML integration
  - Handles image processing and classification storage
  - Uses ActiveStorage for image management
- Node.js TensorFlow.js server
  - Running on port 3001
  - Handles model loading and predictions
  - Includes image preprocessing with Sharp

## Target Architecture
- Rails application (main app)
  - Will directly communicate with Node.js server
  - Keeps existing ActiveStorage setup
- Enhanced Node.js server with TensorFlow.js
  - Combines functionality from FastAPI and existing Node server
  - Single point of contact for ML operations

## Progress Log

### Completed Steps (2023-12-28)
1. **Removed Local Training Components**
   - Deleted entire `ml_service` directory containing:
     - Python training code (`prepare_data.py`)
     - FastAPI service (`app/main.py`)
     - Docker configuration files (`Dockerfile`, `docker-compose.yml`)
     - Python dependencies (`requirements.txt`)
     - Local model files
   - Verified `Procfile.dev` has no ML-related processes
   - Confirmed `ml.rake` only contains necessary tasks:
     - `classify` task for running predictions
     - `test_image` task for testing image processing
     - `fetch_images` task for satellite imagery

2. **Set Up Node.js Server Structure**
   - Created `node_service` directory for encapsulation
   - Set up fresh Node.js project with latest dependencies
   - Added proper `.gitignore` entries for Node.js files
   - Created comprehensive README.md for the service
   - Preserved and migrated existing model files:
     - Moved `model.json`, `metadata.json`, and `weights.bin`
     - Confirmed model metadata shows correct labels: ['result', 'non-results']

3. **Initial Server Test**
   - Successfully started server on port 3001
   - Model loaded correctly
   - Metadata loaded and validated
   - Server ready for predictions

4. **Updated Rails Integration**
   - Enhanced `Ml::ClassifierService` with server management:
     - Added `start_server` method to handle Node.js server startup
     - Added `ensure_server_running` method with retry logic
     - Server logs now go to `log/node_service.log` and `log/node_service.error.log`
   - Updated rake tasks to manage server lifecycle:
     - `ml:classify` now starts the server automatically
     - `ml:test_image` now starts the server automatically
     - Added proper error handling and status checks
   - Removed FastAPI endpoint references
   - Kept existing batch processing functionality

### Current Status
- Node.js server starts automatically when needed
- Server health is checked with retries
- Proper logging setup for both Rails and Node.js components
- Clean separation of concerns:
  - Rails handles: Image storage, classification records, task orchestration
  - Node.js handles: Model loading, image preprocessing, predictions

### Observations
1. Model Information:
   - Using TensorFlow.js version 1.3.1 (from model metadata)
   - Image size: 224x224
   - Binary classification: ['result', 'non-results']
   - Model name: 'tm-my-image-model'

## Next Steps

1. **Testing & Validation**
   - Test automatic server startup
   - Test image preprocessing pipeline
   - Verify classification results match previous implementation
   - Test batch processing functionality
   - Validate error handling and recovery
   - Test server logs and error reporting

2. **Final Cleanup**
   - Update documentation
   - Remove unused environment variables
   - Update development setup instructions

## Technical Details

### Existing Endpoints to Preserve
- POST `/predict` - Main classification endpoint
- POST `/test-image` - Image processing test endpoint
- GET `/health` - Health check endpoint

### Data Formats
- Input: Base64 encoded image
- Output: Array of class probabilities
- Image preprocessing: 224x224 RGB format

### Error Handling
- Timeout: 10 seconds (currently set in Rails)
- Proper error messages for:
  - Invalid image data
  - Model loading issues
  - Processing errors
  - Connection timeouts

## Benefits
- Simplified tech stack (removing Python/FastAPI layer)
- Direct communication between Rails and Node.js
- Reuse of existing TensorFlow.js implementation
- Reduced complexity in development environment
- Fewer moving parts in production

## Risks & Mitigation
- Ensure consistent image preprocessing between implementations
- Validate classification accuracy remains the same
- Monitor memory usage in Node.js server
- Implement proper error handling and recovery
- Consider load testing for batch operations 