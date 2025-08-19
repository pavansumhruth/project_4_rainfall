from fastapi import FastAPI
from pydantic import BaseModel
import math
app = FastAPI()
class PredictRequest(BaseModel):
    temperature: float
    humidity: float
    pressure: float
    windSpeed: float
    region: str | None = None
class PredictResponse(BaseModel):
    probability: float
    label: str
    confidence: float
@app.get("/health")
def health():
    return {"status": "ok"}
@app.post("/predict", response_model=PredictResponse)
def predict(req: PredictRequest):
    score = 0.03 * (req.temperature - 20.0) + 0.20 * req.humidity - 0.01 * (req.pressure - 1010.0) - 0.05 * req.windSpeed
    p = 1.0 / (1.0 + math.exp(-score))
    label = "rain" if p >= 0.5 else "no_rain"
    confidence = abs(p - 0.5) * 2.0
    return {"probability": p, "label": label, "confidence": confidence}
