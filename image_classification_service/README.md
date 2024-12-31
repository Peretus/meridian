# TensorFlow.js Model Server

This is a Node.js service that runs inside the Rails application to handle machine learning predictions using TensorFlow.js.

## Setup

1. Install dependencies:
```bash
cd image_classification_service
npm install
```

2. Add model files:
   - Create a `model` directory
   - Add your TensorFlow.js model files:
     - `model.json`
     - `metadata.json`
     - `weights.bin`

## Development

Run the development server with auto-reload:
```bash
npm run dev
```

## Production

Run the production server:
```bash
npm start
```

## API Endpoints

- `GET /health` - Check server and model status
- `POST /predict` - Make predictions on images
- `POST /test-image` - Test image processing pipeline

## Environment Variables

- `PORT` - Server port (default: 3001)
- `HOST` - Server host (default: localhost)

## Integration with Rails

This service is called by the Rails application through the `Ml::ClassifierService` class. The Rails app handles image preparation and classification storage, while this service focuses solely on running the TensorFlow.js model.
Initially, I trained the model locally using Python and FastAPI, but I had trouble running this inside Rails and I switched to training using Teachable Machien and then importing the model directly using an exported TensorFlow.js model.
Seems to be working well so far and it leverages some of the work that folks have done getting TM to where it today. :shrug: