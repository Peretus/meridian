import requests
import sys
from pathlib import Path

def test_health():
    response = requests.get('http://localhost:8000/health')
    print("Health check response:", response.json())
    return response.ok

def test_classification(image_path):
    with open(image_path, 'rb') as f:
        files = {'file': f}
        response = requests.post('http://localhost:8000/classify', files=files)
        if response.ok:
            result = response.json()
            print("\nClassification Results:")
            print(f"Class: {result['class']}")
            print(f"Confidence: {result['confidence']:.2%}")
            print("\nAll probabilities:")
            for class_name, prob in result['all_probabilities'].items():
                print(f"{class_name}: {prob:.2%}")
        else:
            print("Error:", response.text)
        return response.ok

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python test_api.py <path_to_test_image>")
        sys.exit(1)
    
    image_path = sys.argv[1]
    if not Path(image_path).exists():
        print(f"Error: Image file {image_path} does not exist")
        sys.exit(1)
    
    print("Testing API health...")
    if test_health():
        print("\nTesting classification...")
        test_classification(image_path) 