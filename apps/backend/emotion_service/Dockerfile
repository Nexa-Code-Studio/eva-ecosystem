FROM python:3.11-slim

WORKDIR /service

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PORT=8890 \
    ORT_INTRA_OP_THREADS=2 \
    ORT_INTER_OP_THREADS=1 \
    EMOTION_MODEL_PATH=/models/emotion2vec_plus_base_int8.onnx

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY apps/backend/emotion_service/pyproject.toml /service/pyproject.toml
COPY apps/backend/emotion_service/app /service/app

RUN pip install --no-cache-dir ".[gcp]"

# Create non-root runtime user and model mount directory
RUN useradd --create-home --shell /bin/bash appuser \
    && mkdir -p /models \
    && chown -R appuser:appuser /service /models

USER appuser

EXPOSE 8890

# Single worker process -> single ONNX InferenceSession per container (Cloud Run concurrency=1)
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8890} --workers 1"]
