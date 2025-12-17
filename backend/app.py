from flask import Flask, request, jsonify
import joblib
import pandas as pd
import os

app = Flask(__name__)

# Load the model
# Assuming the model is in the header directory relative to this file
MODEL_PATH = os.path.join(os.path.dirname(__file__), 'random_forest_model.joblib')

if not os.path.exists(MODEL_PATH):
    print(f"Error: Model not found at {MODEL_PATH}")
    # In a real app we might exit or handle this better, but for now just print

try:
    model = joblib.load(MODEL_PATH)
    print("Model loaded successfully.")
except Exception as e:
    print(f"Failed to load model: {e}")
    model = None

@app.route('/predict', methods=['POST'])
def predict():
    if not model:
        return jsonify({'error': 'Model not loaded'}), 500

    try:
        data = request.get_json()
        
        # Expected features in the correct order
        feature_names = ['N', 'P', 'K', 'temperature', 'humidity', 'ph', 'rainfall']
        
        # Validate input
        if not data:
             return jsonify({'error': 'No input data provided'}), 400
             
        features = []
        for name in feature_names:
            if name not in data:
                return jsonify({'error': f'Missing feature: {name}'}), 400
            features.append(float(data[name]))
            
        # Create a DataFrame for prediction (to match training layout if needed, though numpy array usually works)
        # Using DataFrame to be safe with feature names if the model cares
        input_df = pd.DataFrame([features], columns=feature_names)
        
        prediction = model.predict(input_df)
        result = prediction[0]
        
        return jsonify({'prediction': result})

    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5001)
