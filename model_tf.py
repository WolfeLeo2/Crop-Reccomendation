import pandas as pd
import numpy as np
import tensorflow as tf
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder, StandardScaler
import json
import os

# Configuration
FILE_PATH = "dataset/Crop_recommendation.csv"
MODEL_DIR = "assets"
os.makedirs(MODEL_DIR, exist_ok=True)

# 1. Load Data
print("Loading data...")
df = pd.read_csv(FILE_PATH)
X = df[['N', 'P', 'K', 'temperature', 'humidity', 'ph', 'rainfall']].values
y = df['label'].values

# 2. Preprocessing
# Encode labels
le = LabelEncoder()
y_encoded = le.fit_transform(y)
NUM_CLASSES = len(le.classes_)
print(f"Number of classes: {NUM_CLASSES}")

# Save labels
labels_path = os.path.join(MODEL_DIR, "labels.txt")
with open(labels_path, "w") as f:
    for label in le.classes_:
        f.write(label + "\n")
print(f"Labels saved to {labels_path}")

# Normalize features
# We will save the scaler parameters to apply them in the app manually or use a normalization layer
scaler = StandardScaler()
X_scaled = scaler.fit_transform(X)

# Metrics for app (Mean and Scale/Std)
mean = scaler.mean_
std = scaler.scale_
norm_params = {
    "mean": mean.tolist(),
    "std": std.tolist()
}
with open(os.path.join(MODEL_DIR, "normalization.json"), "w") as f:
    json.dump(norm_params, f)
print(f"Normalization parameters saved.")

# Split
X_train, X_test, y_train, y_test = train_test_split(X_scaled, y_encoded, test_size=0.2, random_state=42)

# 3. Build Model
model = tf.keras.Sequential([
    tf.keras.layers.Dense(64, activation='relu', input_shape=(7,)),
    tf.keras.layers.Dense(32, activation='relu'),
    tf.keras.layers.Dense(NUM_CLASSES, activation='softmax')
])

model.compile(optimizer='adam',
              loss='sparse_categorical_crossentropy',
              metrics=['accuracy'])

# 4. Train
print("Starting training...")
model.fit(X_train, y_train, epochs=50, validation_data=(X_test, y_test), verbose=1)

# 5. Evaluate
loss, accuracy = model.evaluate(X_test, y_test)
print(f"Test Accuracy: {accuracy * 100:.2f}%")

# 6. Convert to TFLite
print("Converting to TFLite...")
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()

tflite_path = os.path.join(MODEL_DIR, "model.tflite")
with open(tflite_path, "wb") as f:
    f.write(tflite_model)
print(f"TFLite model saved to {tflite_path}")
