"""Isolated stateless FastAPI app for Emotion2Vec+ Base ONNX INT8 inference."""

from __future__ import annotations

import logging
import os
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, Header, HTTPException, Request, status

from app.auth import verify_service_auth
from app.engine import ONNXEmotionEngine
from app.schemas import EmotionPredictResponse, HealthResponse, ReadinessResponse

logger = logging.getLogger(__name__)

CANONICAL_SAMPLE_RATE = 16000
CANONICAL_CHANNELS = 1
BYTES_PER_MS = 32
MIN_SEGMENT_BYTES = 250 * BYTES_PER_MS  # 0.25s minimum accepted by server
MAX_SEGMENT_BYTES = 10_000 * BYTES_PER_MS  # 10s hard upper bound (320,000 bytes)

engine = ONNXEmotionEngine()


def create_app(custom_engine: ONNXEmotionEngine | None = None) -> FastAPI:
    active_engine = custom_engine or engine

    @asynccontextmanager
    async def lifespan(_app: FastAPI):
        if os.getenv("EMOTION_SKIP_STARTUP_LOAD", "false").lower() != "true":
            active_engine.load()
        yield

    application = FastAPI(
        title="Eva Isolated Speech Emotion Service",
        version="0.1.0",
        lifespan=lifespan,
    )

    @application.get("/health", response_model=HealthResponse)
    async def health() -> HealthResponse:
        return HealthResponse(status="ok")

    @application.get("/ready", response_model=ReadinessResponse)
    async def ready() -> ReadinessResponse:
        if not active_engine.is_ready:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Emotion model is not loaded yet",
            )
        return ReadinessResponse(
            ready=True,
            model=active_engine.model_name,
            model_revision=active_engine.model_revision,
            runtime=active_engine.runtime_name,
            precision=active_engine.precision_name,
        )

    @application.post(
        "/v1/emotions/predict",
        response_model=EmotionPredictResponse,
        dependencies=[Depends(verify_service_auth)],
    )
    async def predict_emotion(
        request: Request,
        x_segment_id: str = Header(..., alias="X-Segment-Id", min_length=1, max_length=128),
        x_schema_version: int = Header(default=1, alias="X-Schema-Version"),
        x_sample_rate: int = Header(default=CANONICAL_SAMPLE_RATE, alias="X-Sample-Rate"),
        x_channels: int = Header(default=CANONICAL_CHANNELS, alias="X-Channels"),
        x_sample_format: str = Header(default="pcm_s16le", alias="X-Sample-Format"),
    ) -> EmotionPredictResponse:
        if not active_engine.is_ready:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Emotion model is not ready",
            )

        if x_schema_version != 1:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Unsupported schema version")
        if x_sample_rate != CANONICAL_SAMPLE_RATE:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Sample rate must be 16000 Hz")
        if x_channels != CANONICAL_CHANNELS:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Audio must be mono (1 channel)")
        if x_sample_format.lower() != "pcm_s16le":
            raise HTTPException(status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, detail="Expected pcm_s16le")

        body = await request.body()
        if len(body) < MIN_SEGMENT_BYTES:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="PCM segment too short")
        if len(body) > MAX_SEGMENT_BYTES:
            raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="PCM segment too large")
        if len(body) % 2 != 0:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="PCM16 payload must be 2-byte aligned")

        try:
            scores, primary, secondary, confidence, inference_ms = active_engine.predict(body)
        except ValueError as val_err:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(val_err)) from val_err

        return EmotionPredictResponse(
            schema_version=1,
            segment_id=x_segment_id,
            status="ok",
            model=active_engine.model_name,
            model_revision=active_engine.model_revision,
            runtime=active_engine.runtime_name,
            precision=active_engine.precision_name,
            scores=scores,
            primary_emotion=primary,
            secondary_emotion=secondary,
            confidence=confidence,
            inference_ms=inference_ms,
        )

    return application


app = create_app()
