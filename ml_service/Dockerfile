# Use an official TensorFlow runtime as the base image
FROM tensorflow/tensorflow:2.15.0

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3-pip \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better cache usage
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application
COPY . .

# Make port 8000 available
EXPOSE 8000

# Start the FastAPI app with uvicorn
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"] 