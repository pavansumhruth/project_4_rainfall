from fastapi import FastAPI
from pydantic import BaseModel, Field
import math
import logging
import os
from typing import Tuple

import numpy as np
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.linear_model import LogisticRegression
import joblib


def _setup_logger() -> logging.Logger:
    level_name = os.getenv("LOG_LEVEL", "INFO").upper()
    level = getattr(logging, level_name, logging.INFO)
    logging.basicConfig(level=level, format="%(asctime)s %(levelname)s %(name)s - %(message)s")
    return logging.getLogger("ml-service")


logger = _setup_logger()
app = FastAPI()


class PredictRequest(BaseModel):
    temperature: float = Field(..., ge=-60.0, le=60.0)
    humidity: float = Field(..., ge=0.0, le=1.0)
    pressure: float = Field(..., ge=870.0, le=1085.0)
    windSpeed: float = Field(..., ge=0.0, le=60.0)
    region: str | None = None


class PredictResponse(BaseModel):
    probability: float
    label: str
    confidence: float


MODEL_PATH = os.getenv("MODEL_PATH", "/app/model.joblib")
MODEL_VERSION = os.getenv("MODEL_VERSION", "baseline-logistic-1")


def _generate_synthetic_dataset(n_samples: int = 5000, seed: int = 42) -> Tuple[np.ndarray, np.ndarray]:
    rng = np.random.default_rng(seed)
    temperature = rng.normal(loc=20.0, scale=10.0, size=n_samples)
    humidity = rng.beta(a=2.0, b=2.0, size=n_samples)  # 0..1
    pressure = rng.normal(loc=1010.0, scale=10.0, size=n_samples)
    wind_speed = np.abs(rng.normal(loc=4.0, scale=3.0, size=n_samples))
    X = np.column_stack([temperature, humidity, pressure, wind_speed])
    # Same heuristic as the initial baseline to synthesize labels
    score = 0.03 * (temperature - 20.0) + 0.20 * humidity - 0.01 * (pressure - 1010.0) - 0.05 * wind_speed
    p = 1.0 / (1.0 + np.exp(-score))
    y = rng.binomial(1, p)
    return X, y


def _train_default_model() -> Pipeline:
    logger.info("Training default logistic regression model on synthetic data ...")
    X, y = _generate_synthetic_dataset()
    pipeline = Pipeline([
        ("scaler", StandardScaler()),
        ("lr", LogisticRegression(max_iter=1000))
    ])
    pipeline.fit(X, y)
    return pipeline


def _load_or_train_model() -> Pipeline:
    try:
        if os.path.exists(MODEL_PATH):
            model = joblib.load(MODEL_PATH)
            logger.info("Loaded model from %s", MODEL_PATH)
            return model
        model = _train_default_model()
        try:
            joblib.dump(model, MODEL_PATH)
            logger.info("Saved trained model to %s", MODEL_PATH)
        except Exception as save_err:
            logger.warning("Could not save model to %s: %s", MODEL_PATH, save_err)
        return model
    except Exception as err:
        logger.exception("Failed to load/train model: %s", err)
        # As a last resort, provide a trivial fallback that mirrors the heuristic via a lambda-like wrapper
        class _HeuristicModel:
            def predict_proba(self, X: np.ndarray) -> np.ndarray:
                t, h, p, w = X[:, 0], X[:, 1], X[:, 2], X[:, 3]
                score = 0.03 * (t - 20.0) + 0.20 * h - 0.01 * (p - 1010.0) - 0.05 * w
                prob = 1.0 / (1.0 + np.exp(-score))
                return np.column_stack([1.0 - prob, prob])

        logger.warning("Using heuristic fallback model in memory.")
        return _HeuristicModel()


model: Pipeline = _load_or_train_model()


@app.get("/health")
def health():
    return {"status": "ok", "model_path": MODEL_PATH, "model_version": MODEL_VERSION}


@app.post("/predict", response_model=PredictResponse)
def predict(req: PredictRequest):
    X = np.array([[req.temperature, req.humidity, req.pressure, req.windSpeed]], dtype=float)
    try:
        proba = float(model.predict_proba(X)[0, 1])
    except Exception as err:
        logger.exception("Model predict failed, using heuristic: %s", err)
        score = 0.03 * (req.temperature - 20.0) + 0.20 * req.humidity - 0.01 * (req.pressure - 1010.0) - 0.05 * req.windSpeed
        proba = 1.0 / (1.0 + math.exp(-score))
    label = "rain" if proba >= 0.5 else "no_rain"
    confidence = abs(proba - 0.5) * 2.0
    logger.info(
        "predicted label=%s proba=%.4f confidence=%.4f for temp=%.2f hum=%.2f pres=%.2f wind=%.2f region=%s",
        label,
        proba,
        confidence,
        req.temperature,
        req.humidity,
        req.pressure,
        req.windSpeed,
        req.region,
    )
    return {"probability": proba, "label": label, "confidence": confidence}
