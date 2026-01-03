"""
FarmWise Crop Recommendation API
FastAPI backend for ML model inference - Ready for Render deployment
"""
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import joblib
import numpy as np
import os
from typing import Dict

# Initialize FastAPI app
app = FastAPI(
    title="FarmWise Crop Recommendation API",
    description="ML-powered crop recommendation based on soil and weather parameters",
    version="1.0.0"
)

# Enable CORS for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, restrict to your app's domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load model at startup
MODEL_PATH = os.path.join(os.path.dirname(__file__), "random_forest_model.joblib")
model = None

@app.on_event("startup")
async def load_model():
    global model
    try:
        model = joblib.load(MODEL_PATH)
        print(f"✅ Model loaded successfully from {MODEL_PATH}")
    except Exception as e:
        print(f"❌ Failed to load model: {e}")


# Request/Response models
class PredictionRequest(BaseModel):
    """Input parameters for crop recommendation"""
    N: float = Field(..., description="Nitrogen content in soil (kg/ha)", ge=0)
    P: float = Field(..., description="Phosphorus content in soil (kg/ha)", ge=0)
    K: float = Field(..., description="Potassium content in soil (kg/ha)", ge=0)
    temperature: float = Field(..., description="Average temperature (°C)", ge=-50, le=60)
    humidity: float = Field(..., description="Relative humidity (%)", ge=0, le=100)
    ph: float = Field(..., description="Soil pH", ge=0, le=14)
    rainfall: float = Field(..., description="Average rainfall (mm)", ge=0)
    
    class Config:
        json_schema_extra = {
            "example": {
                "N": 90,
                "P": 42,
                "K": 43,
                "temperature": 20.8,
                "humidity": 82.0,
                "ph": 6.5,
                "rainfall": 202.9
            }
        }


class PredictionResponse(BaseModel):
    """Crop recommendation result"""
    prediction: str
    confidence: float | None = None


class HealthResponse(BaseModel):
    """Health check response"""
    status: str
    model_loaded: bool


# Endpoints
@app.get("/", response_model=Dict[str, str])
async def root():
    """Root endpoint - API info"""
    return {
        "name": "FarmWise Crop Recommendation API",
        "version": "1.0.0",
        "docs": "/docs"
    }


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint for Render"""
    return HealthResponse(
        status="healthy" if model else "degraded",
        model_loaded=model is not None
    )


@app.post("/predict", response_model=PredictionResponse)
async def predict(request: PredictionRequest):
    """
    Get crop recommendation based on soil and weather parameters
    
    - **N**: Nitrogen content in soil (kg/ha)
    - **P**: Phosphorus content in soil (kg/ha)  
    - **K**: Potassium content in soil (kg/ha)
    - **temperature**: Average temperature in Celsius
    - **humidity**: Relative humidity percentage
    - **ph**: Soil pH value (0-14)
    - **rainfall**: Average rainfall in mm
    """
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    try:
        # Prepare features in correct order
        features = np.array([[
            request.N,
            request.P,
            request.K,
            request.temperature,
            request.humidity,
            request.ph,
            request.rainfall
        ]])
        
        # Make prediction
        prediction = model.predict(features)[0]
        
        # Get confidence if available (for RandomForest)
        confidence = None
        if hasattr(model, 'predict_proba'):
            proba = model.predict_proba(features)[0]
            confidence = float(max(proba))
        
        return PredictionResponse(
            prediction=prediction,
            confidence=confidence
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction error: {str(e)}")


# For local development
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
