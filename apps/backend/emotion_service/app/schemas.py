"""Versioned Pydantic v2 contracts for the isolated Emotion Inference Microservice."""

from __future__ import annotations

import math

from pydantic import BaseModel, field_validator

EMOTION_CLASSES: tuple[str, ...] = (
    "angry",
    "disgusted",
    "fearful",
    "happy",
    "neutral",
    "other",
    "sad",
    "surprised",
    "unknown",
)


class HealthResponse(BaseModel):
    status: str = "ok"
    service: str = "eva-emotion-service"


class ReadinessResponse(BaseModel):
    ready: bool
    model: str
    model_revision: str
    runtime: str
    precision: str


class EmotionPredictResponse(BaseModel):
    schema_version: int = 1
    segment_id: str
    status: str = "ok"
    model: str
    model_revision: str
    runtime: str
    precision: str
    scores: dict[str, float]
    primary_emotion: str
    secondary_emotion: str | None = None
    confidence: float
    inference_ms: float

    @field_validator("scores")
    @classmethod
    def _validate_scores(cls, value: dict[str, float]) -> dict[str, float]:
        for cls_name in EMOTION_CLASSES:
            if cls_name not in value:
                raise ValueError(f"Missing canonical emotion class '{cls_name}'")
            score = value[cls_name]
            if not isinstance(score, int | float) or not math.isfinite(score):
                raise ValueError(f"Non-finite score for '{cls_name}': {score}")
            if score < 0.0 or score > 1.0:
                raise ValueError(f"Out-of-range score for '{cls_name}': {score}")
        return {k: float(v) for k, v in value.items()}
