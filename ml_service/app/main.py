from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import tensorflow as tf
import numpy as np
from PIL import Image, ImageOps
import io

# Disable scientific notation for clarity
np.set_printoptions(suppress=True)

app = FastAPI(title="Image Classification API")

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global variables for model and labels
interpreter = None
class_names = []

@app.on_event("startup")
async def load_model():
    global interpreter, class_names
    try:
        # Convert model to TFLite format
        converter = tf.lite.TFLiteConverter.from_keras_model_path("models/classifier/keras_model.h5")
        tflite_model = converter.convert()
        
        # Save the TFLite model
        with open("models/classifier/model.tflite", "wb") as f:
            f.write(tflite_model)
        
        # Load the TFLite model
        interpreter = tf.lite.Interpreter(model_path="models/classifier/model.tflite")
        interpreter.allocate_tensors()
        
        # Get input and output details
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()
        print(f"Input details: {input_details}")
        print(f"Output details: {output_details}")
        
        # Load labels
        try:
            class_names = open("models/classifier/labels.txt", "r").readlines()
            print(f"Labels loaded: {class_names}")
        except FileNotFoundError:
            print("Labels file not found, will use numeric indices")
            class_names = [str(i) for i in range(len(output_details[0]['shape']))]
            
        print("Model loaded successfully")
        
    except Exception as e:
        print(f"Error loading model: {e}")
        import traceback
        traceback.print_exc()

def preprocess_image(image: Image.Image):
    """Preprocess the image exactly as in the Teachable Machine example."""
    # Convert to RGB
    image = image.convert("RGB")
    
    # Create the array of the right shape
    data = np.ndarray(shape=(1, 224, 224, 3), dtype=np.float32)
    
    # Resize and crop from center
    size = (224, 224)
    image = ImageOps.fit(image, size, Image.Resampling.LANCZOS)
    
    # Turn the image into a numpy array
    image_array = np.asarray(image)
    
    # Normalize the image
    normalized_image_array = (image_array.astype(np.float32) / 127.5) - 1
    
    # Load the image into the array
    data[0] = normalized_image_array
    
    return data

@app.post("/classify")
async def classify_image(file: UploadFile = File(...)):
    if not file:
        raise HTTPException(status_code=400, detail="No file provided")
    
    try:
        # Read and preprocess the image
        contents = await file.read()
        image = Image.open(io.BytesIO(contents))
        processed_image = preprocess_image(image)
        
        # Make prediction using TFLite
        if interpreter is None:
            raise HTTPException(status_code=500, detail="Model not loaded")
        
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()
        
        interpreter.set_tensor(input_details[0]['index'], processed_image)
        interpreter.invoke()
        prediction = interpreter.get_tensor(output_details[0]['index'])
        
        index = np.argmax(prediction[0])
        class_name = class_names[index]
        confidence_score = float(prediction[0][index])
        
        # Remove the numeric prefix and newline from class name (format: "0 Class Name\n")
        clean_class_name = class_name.split(" ", 1)[1].strip() if " " in class_name else class_name.strip()
        
        return {
            "class": clean_class_name,
            "confidence": confidence_score,
            "all_probabilities": {
                name.split(" ", 1)[1].strip() if " " in name else name.strip(): float(prob)
                for name, prob in zip(class_names, prediction[0])
            },
            "status": "success"
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "model_loaded": interpreter is not None,
        "num_classes": len(class_names) if class_names else None
    } 