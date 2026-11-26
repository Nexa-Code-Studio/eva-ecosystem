"""Singleton ONNX Runtime CPU INT8 inference engine with zero-disk PCM16 preprocessing."""

from __future__ import annotations

import hashlib
import logging
import math
import os
import time
from pathlib import Path
from typing import Any

import numpy as np

from app.schemas import EMOTION_CLASSES

logger = logging.getLogger(__name__)


def _softmax(logits: np.ndarray) -> np.ndarray:
    shifted = logits - np.max(logits)
    exps = np.exp(shifted)
    denom = np.sum(exps)
    if not np.isfinite(denom) or denom <= 0.0:
        raise ValueError("Invalid softmax denominator")
    return exps / denom


def verify_file_sha256(file_path: Path, expected_sha256: str) -> None:
    hasher = hashlib.sha256()
    with file_path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            hasher.update(chunk)
    actual = hasher.hexdigest().lower()
    if actual != expected_sha256.strip().lower():
        raise RuntimeError(
            f"ONNX model SHA-256 mismatch for {file_path}: expected={expected_sha256}, actual={actual}"
        )


def pcm16le_to_float32(pcm_bytes: bytes, normalize_layer: bool = True) -> np.ndarray:
    """Convert raw signed PCM16 LE mono bytes in-memory to float32 waveform (no disk I/O)."""
    if len(pcm_bytes) == 0 or len(pcm_bytes) % 2 != 0:
        raise ValueError("PCM16 payload must be non-empty and 2-byte aligned")

    waveform = np.frombuffer(pcm_bytes, dtype="<i2").astype(np.float32) / 32768.0
    if not np.all(np.isfinite(waveform)):
        raise ValueError("PCM waveform contains non-finite values")

    if normalize_layer:
        mean = float(np.mean(waveform))
        std = float(np.std(waveform))
        if std > 1e-6:
            waveform = (waveform - mean) / std
        else:
            waveform = waveform - mean
    return waveform


class ONNXEmotionEngine:
    """Stateless singleton inference engine holding one ONNX Runtime InferenceSession per process."""

    def __init__(
        self,
        *,
        backend: str | None = None,
        model_path: str | None = None,
        model_name: str | None = None,
        model_revision: str | None = None,
        model_sha256: str | None = None,
        intra_op_threads: int | None = None,
        inter_op_threads: int | None = None,
        normalize_layer: bool = True,
    ) -> None:
        self.app_env = os.getenv("APP_ENV", "development").strip().lower()
        self.backend = (backend or os.getenv("EMOTION_ENGINE_BACKEND", "onnxruntime")).strip().lower()
        self.model_path = Path(model_path or os.getenv("EMOTION_MODEL_PATH", "/models/emotion2vec_plus_base_int8.onnx"))
        self.model_name = model_name or os.getenv("EMOTION_MODEL_NAME", "emotion2vec_plus_base")
        self.model_revision = model_revision or os.getenv("EMOTION_MODEL_REVISION", "pinned-local")
        self.model_sha256 = (model_sha256 or os.getenv("EMOTION_MODEL_SHA256", "")).strip()
        self.intra_op_threads = intra_op_threads or int(os.getenv("ORT_INTRA_OP_THREADS", "2"))
        self.inter_op_threads = inter_op_threads or int(os.getenv("ORT_INTER_OP_THREADS", "1"))
        self.normalize_layer = normalize_layer

        self._session: Any = None
        self._input_name: str = ""
        self._ready: bool = False

    @property
    def is_ready(self) -> bool:
        return self._ready

    @property
    def runtime_name(self) -> str:
        return "mock" if self.backend == "mock" else "onnxruntime"

    @property
    def precision_name(self) -> str:
        return "mock" if self.backend == "mock" else os.getenv("EMOTION_MODEL_PRECISION", "int8")

    def load(self) -> None:
        """Warm-load singleton InferenceSession during service lifespan startup."""
        if self._ready:
            return

        if self.backend == "mock":
            if self.app_env == "production":
                raise RuntimeError("EMOTION_ENGINE_BACKEND='mock' is prohibited in production")
            logger.warning("[EMOTION ENGINE] Starting in non-production MOCK backend mode.")
            self._ready = True
            return

        if not self.model_path.is_file():
            raise FileNotFoundError(
                f"Pinned ONNX model artifact not found at '{self.model_path}'. "
                "Bake the verified ONNX INT8 model into the image or mount it before startup."
            )

        if self.model_sha256:
            verify_file_sha256(self.model_path, self.model_sha256)
            logger.info("[EMOTION ENGINE] Verified ONNX model SHA-256 checksum.")

        import onnxruntime as ort

        sess_opts = ort.SessionOptions()
        sess_opts.intra_op_num_threads = self.intra_op_threads
        sess_opts.inter_op_num_threads = self.inter_op_threads
        sess_opts.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL

        start_t = time.perf_counter()
        self._session = ort.InferenceSession(
            str(self.model_path),
            sess_options=sess_opts,
            providers=["CPUExecutionProvider"],
        )
        inputs = self._session.get_inputs()
        if not inputs:
            raise RuntimeError("ONNX model exposes zero inputs")
        self._input_name = inputs[0].name
        load_ms = (time.perf_counter() - start_t) * 1000.0
        self._ready = True
        logger.info(
            "[EMOTION ENGINE] Loaded '%s' (%s, input='%s', intra=%d, inter=%d) in %.1fms",
            self.model_name,
            self.precision_name,
            self._input_name,
            self.intra_op_threads,
            self.inter_op_threads,
            load_ms,
        )

    def predict(self, pcm_bytes: bytes) -> tuple[dict[str, float], str, str | None, float, float]:
        """Run CPU-bound synchronous inference on canonical 16kHz PCM16 LE mono bytes.

        Returns:
            (scores_dict, primary_emotion, secondary_emotion, confidence, inference_ms)
        """
        if not self._ready:
            raise RuntimeError("ONNXEmotionEngine is not ready")

        waveform = pcm16le_to_float32(pcm_bytes, normalize_layer=self.normalize_layer)
        start_t = time.perf_counter()

        if self.backend == "mock":
            # Deterministic energy-responsive mock distribution for local/CI HTTP contract tests
            energy = float(np.sqrt(np.mean(waveform**2))) if waveform.size else 0.0
            base = np.array([0.02, 0.01, 0.06, 0.08, 0.56, 0.02, 0.21, 0.02, 0.02], dtype=np.float32)
            if energy > 0.5:
                base[6] += 0.15
                base[4] -= 0.15
            probs = base / np.sum(base)
        else:
            input_tensor = np.expand_dims(waveform, axis=0)  # shape (1, num_samples)
            raw_outputs = self._session.run(None, {self._input_name: input_tensor})
            vec = np.asarray(raw_outputs[0], dtype=np.float32).reshape(-1)
            if vec.shape[0] != len(EMOTION_CLASSES):
                raise ValueError(f"Expected {len(EMOTION_CLASSES)} emotion classes, got {vec.shape[0]}")
            if not np.all(np.isfinite(vec)):
                raise ValueError("ONNX model returned non-finite outputs")
            # Normalize via softmax if output looks like unnormalized logits
            if float(np.min(vec)) < 0.0 or float(np.max(vec)) > 1.0 or not math.isclose(float(np.sum(vec)), 1.0, abs_tol=0.05):
                probs = _softmax(vec)
            else:
                probs = vec

        inference_ms = round((time.perf_counter() - start_t) * 1000.0, 2)
        scores = {cls: round(float(probs[idx]), 6) for idx, cls in enumerate(EMOTION_CLASSES)}
        ordered = sorted(scores.items(), key=lambda item: item[1], reverse=True)
        primary_emotion, confidence = ordered[0]
        secondary_emotion = ordered[1][0] if len(ordered) > 1 else None
        return scores, primary_emotion, secondary_emotion, confidence, inference_ms
