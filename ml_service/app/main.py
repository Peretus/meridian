import os
import io
from typing import List
import numpy as np
from PIL import Image
import tensorflow as tf
from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global variables for model and labels
model = None
labels = []

def load_model():
    global model, labels
    try:
        # Load the model with .keras extension
        model = tf.keras.models.load_model("models/classifier/model.keras")
        
        # Load labels
        with open("models/classifier/labels.txt", "r") as f:
            labels = [line.split()[1] for line in f.readlines()]
            
        print(f"Model loaded successfully. Labels: {labels}")
        return True
    except Exception as e:
        print(f"Error loading model: {str(e)}")
        return False

def preprocess_image(image_data: bytes) -> np.ndarray:
    # Open image from bytes
    image = Image.open(io.BytesIO(image_data))
    
    # Convert to RGB if needed
    if image.mode != "RGB":
        image = image.convert("RGB")
    
    # Resize to match model's expected input
    image = image.resize((224, 224))
    
    # Convert to numpy array and normalize
    img_array = np.array(image)
    img_array = img_array.astype(np.float32) / 255.0
    
    # Add batch dimension
    return np.expand_dims(img_array, 0)

@app.on_event("startup")
async def startup_event():
    load_model()

@app.get("/health")
async def health_check():
    return {"status": "healthy", "model_loaded": model is not None}

@app.post("/classify")
async def classify_image(file: UploadFile = File(...)):
    if not model:
        return {"error": "Model not loaded"}
    
    try:
        # Read and preprocess the image
        contents = await file.read()
        img_array = preprocess_image(contents)
        
        # Make prediction (categorical output)
        predictions = model.predict(img_array)[0]
        anchorage_prob = float(predictions[0])  # Probability of anchorage
        
        # Convert to class and probability
        is_anchorage = anchorage_prob >= 0.5
        confidence = anchorage_prob if is_anchorage else (1 - anchorage_prob)
        predicted_class = "anchorage" if is_anchorage else "not_anchorage"
        
        return {
            "class": predicted_class,
            "confidence": float(confidence),
            "probabilities": {
                "anchorage": float(anchorage_prob),
                "not_anchorage": float(1 - anchorage_prob)
            }
        }
    except Exception as e:
        return {"error": str(e)} 