const express = require('express');
const tf = require('@tensorflow/tfjs-node');
const cors = require('cors');
const fs = require('fs').promises;
const path = require('path');
const sharp = require('sharp');

const app = express();
app.use(express.json({ limit: '50mb' }));
app.use(cors());

let model = null;

// Load the model
async function loadModel() {
    try {
        // We'll need to update this path once we have the new model
        const modelPath = path.join(__dirname, 'model', 'model.json');
        const metadataPath = path.join(__dirname, 'model', 'metadata.json');
        
        // Load and validate metadata first
        const metadata = JSON.parse(await fs.readFile(metadataPath, 'utf8'));
        console.log('Model metadata:', metadata);
        
        // Load the model
        model = await tf.loadLayersModel('file://' + modelPath);
        console.log('Model loaded successfully');
        
        // Warm up the model with a dummy prediction
        const dummyInput = tf.zeros([1, metadata.imageSize, metadata.imageSize, 3]);
        const warmup = model.predict(dummyInput);
        warmup.dispose();
        dummyInput.dispose();
        
        return true;
    } catch (error) {
        console.error('Error loading model:', error);
        return false;
    }
}

// Convert base64 to tensor
async function base64ToTensor(base64String) {
    try {
        const buffer = Buffer.from(base64String, 'base64');
        
        // Process image with sharp
        const { data, info } = await sharp(buffer)
            .resize(224, 224, { fit: 'fill' })
            .removeAlpha()
            .raw()
            .toBuffer({ resolveWithObject: true });
        
        // Convert to float32 and normalize
        const float32Data = new Float32Array(data.length);
        for (let i = 0; i < data.length; i++) {
            float32Data[i] = data[i] / 255.0;
        }
        
        return tf.tensor3d(float32Data, [224, 224, 3]);
    } catch (error) {
        console.error('Error in base64ToTensor:', error);
        throw error;
    }
}

// Prediction endpoint
app.post('/predict', async (req, res) => {
    if (!model) {
        return res.status(500).json({ error: 'Model not loaded' });
    }

    try {
        const imageData = req.body.image;
        if (!imageData) {
            return res.status(400).json({ error: 'No image data provided' });
        }
        
        const tensor = await base64ToTensor(imageData);
        
        // Use tf.tidy for automatic memory cleanup
        const result = tf.tidy(() => {
            const batched = tensor.expandDims(0);
            return model.predict(batched);
        });
        
        const probabilities = await result.data();
        
        // Clean up
        tf.dispose([tensor, result]);
        
        res.json({ predictions: Array.from(probabilities) });
    } catch (error) {
        console.error('Prediction error:', error);
        res.status(500).json({ 
            error: 'Prediction failed',
            details: error.message
        });
    }
});

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ 
        status: 'healthy',
        modelLoaded: model !== null,
        tfjs_version: tf.version.tfjs
    });
});

// Test image processing endpoint
app.post('/test-image', async (req, res) => {
    try {
        const imageData = req.body.image;
        if (!imageData) {
            return res.status(400).json({ error: 'No image data provided' });
        }
        
        const tensor = await base64ToTensor(imageData);
        const shape = tensor.shape;
        
        // Clean up
        tensor.dispose();
        
        res.json({ 
            success: true,
            message: 'Image processed successfully',
            tensorShape: shape
        });
    } catch (error) {
        res.status(400).json({ 
            error: 'Image processing failed',
            details: error.message
        });
    }
});

const PORT = process.env.PORT || 3001;
const HOST = process.env.HOST || 'localhost';

// Start server
app.listen(PORT, HOST, async () => {
    console.log(`Starting server on ${HOST}:${PORT}...`);
    const modelLoaded = await loadModel();
    if (modelLoaded) {
        console.log('Server ready for predictions');
    } else {
        console.log('Server started but model failed to load');
    }
}); 