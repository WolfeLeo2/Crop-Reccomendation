import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
import joblib # For saving the final model

# --- Configuration ---
FILE_PATH = "dataset/Crop_recommendation.csv"
TEST_SIZE = 0.20 # Use 20% of data for testing
RANDOM_STATE = 42 # For reproducibility of results

# 1. Load the Data
df = pd.read_csv(FILE_PATH)

# 2. Define Features (X) and Target (y)
# Features include N, P, K, temperature, humidity, ph, and rainfall
X = df[['N', 'P', 'K', 'temperature', 'humidity', 'ph', 'rainfall']]
y = df['label'] # The crop name is the target variable

# 3. Split the Data into Training and Testing Sets
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=TEST_SIZE, shuffle=True, random_state=RANDOM_STATE
)

# 4. Train the Random Forest Model
# n_estimators=100 is a robust default; n_jobs=-1 uses all CPU cores for speed
rf_classifier = RandomForestClassifier(
    n_estimators=100, 
    random_state=RANDOM_STATE, 
    n_jobs=-1
)

print("Starting Random Forest Training...")
rf_classifier.fit(X_train, y_train)
print("Training Complete.")

# 5. Make Predictions
y_pred = rf_classifier.predict(X_test)

# 6. Model Evaluation and Reporting
print("\n--- Model Evaluation ---")
test_accuracy = accuracy_score(y_test, y_pred)
print(f"Test Accuracy: {test_accuracy * 100:.2f}%")

print("\nClassification Report:\n", classification_report(y_test, y_pred))

# 7. Extract and Display Feature Importance (Crucial for the report!)
importance = rf_classifier.feature_importances_
feature_names = X.columns
feature_importance_df = pd.DataFrame({
    'Feature': feature_names, 
    'Importance': importance
})
feature_importance_df = feature_importance_df.sort_values(
    by='Importance', 
    ascending=False
)

print("\n--- Feature Importance Table (for Report) ---")
print(feature_importance_df.to_markdown(index=False))

# --- Visualization for Report ---
# Save the trained model for later use in the Flask API
joblib.dump(rf_classifier, 'random_forest_model.joblib')
print("\nTrained model saved as 'random_forest_model.joblib'")