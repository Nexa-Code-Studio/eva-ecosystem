#!/usr/bin/env python3
"""Verify ONNX INT8 model artifact checksum, schema, 9-class mapping, and FP32 vs INT8 parity.

Usage:
    python3 apps/backend/emotion_service/scripts/export_and_verify_onnx.py \
        --int8-model /models/emotion2vec_plus_base_int8.onnx \
        --fp32-model /models/emotion2vec_plus_base_fp32.onnx \
        --wav-dir tests/test_emotion
"""

from __future__ import annotations

import argparse
import hashlib
import json
import time
import wave
from pathlib import Path

import numpy as np

EMOTION_CLASSES = (
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


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def load_pcm16_wav(wav_path: Path) -> np.ndarray:
    with wave.open(str(wav_path), "rb") as wf:
        if wf.getframerate() != 16000 or wf.getnchannels() != 1 or wf.getsampwidth() != 2:
            raise ValueError(f"{wav_path} must be 16kHz mono PCM16 WAV")
        raw = wf.readframes(wf.getnframes())
    arr = np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768.0
    std = float(np.std(arr))
    return (arr - float(np.mean(arr))) / (std if std > 1e-6 else 1.0)


def softmax(x: np.ndarray) -> np.ndarray:
    s = x - np.max(x)
    e = np.exp(s)
    return e / np.sum(e)


def run_onnx(session, waveform: np.ndarray) -> tuple[np.ndarray, float]:
    input_name = session.get_inputs()[0].name
    t0 = time.perf_counter()
    out = session.run(None, {input_name: np.expand_dims(waveform, axis=0)})
    ms = (time.perf_counter() - t0) * 1000.0
    vec = np.asarray(out[0], dtype=np.float32).reshape(-1)
    if vec.shape[0] != len(EMOTION_CLASSES):
        raise ValueError(f"Expected 9 classes, got {vec.shape[0]}")
    return softmax(vec), ms


def main() -> None:
    parser = argparse.ArgumentParser(description="Verify Emotion2Vec+ Base ONNX INT8 artifact & parity")
    parser.add_argument("--int8-model", type=Path, required=True, help="Path to ONNX INT8 model")
    parser.add_argument("--fp32-model", type=Path, default=None, help="Optional FP32 ONNX model for parity check")
    parser.add_argument("--wav-dir", type=Path, default=None, help="Directory containing 16kHz mono PCM16 WAV fixtures")
    parser.add_argument("--threads", type=int, default=2, help="ORT intra_op_num_threads")
    args = parser.parse_args()

    import onnxruntime as ort

    opts = ort.SessionOptions()
    opts.intra_op_num_threads = args.threads
    opts.inter_op_num_threads = 1

    int8_sha = sha256_file(args.int8_model)
    int8_sess = ort.InferenceSession(str(args.int8_model), sess_options=opts, providers=["CPUExecutionProvider"])
    fp32_sess = (
        ort.InferenceSession(str(args.fp32_model), sess_options=opts, providers=["CPUExecutionProvider"])
        if args.fp32_model
        else None
    )

    report: dict[str, object] = {
        "int8_model": str(args.int8_model),
        "int8_sha256": int8_sha,
        "int8_size_bytes": args.int8_model.stat().st_size,
        "inputs": [{"name": i.name, "shape": i.shape, "type": i.type} for i in int8_sess.get_inputs()],
        "outputs": [{"name": o.name, "shape": o.shape, "type": o.type} for o in int8_sess.get_outputs()],
        "samples": [],
    }

    wav_files = sorted(args.wav_dir.glob("*.wav")) if args.wav_dir and args.wav_dir.is_dir() else []
    if not wav_files:
        # Synthetic 3s sine test
        t = np.linspace(0.0, 3.0, 48000, endpoint=False, dtype=np.float32)
        waveforms = [("synthetic_3s_sine", 0.2 * np.sin(2.0 * np.pi * 220.0 * t).astype(np.float32))]
    else:
        waveforms = []
        for wf in wav_files:
            try:
                waveforms.append((wf.name, load_pcm16_wav(wf)))
            except ValueError as err:
                report["samples"].append({"file": wf.name, "skipped": str(err)})

    agreements = 0
    compared = 0
    for name, wav in waveforms:
        p_int8, ms_int8 = run_onnx(int8_sess, wav)
        entry: dict[str, object] = {
            "sample": name,
            "int8_ms": round(ms_int8, 2),
            "int8_top": EMOTION_CLASSES[int(np.argmax(p_int8))],
            "int8_scores": {c: round(float(p_int8[i]), 5) for i, c in enumerate(EMOTION_CLASSES)},
        }
        if fp32_sess is not None:
            p_fp32, ms_fp32 = run_onnx(fp32_sess, wav)
            compared += 1
            same_top = int(np.argmax(p_int8)) == int(np.argmax(p_fp32))
            if same_top:
                agreements += 1
            max_abs_diff = float(np.max(np.abs(p_int8 - p_fp32)))
            entry.update(
                {
                    "fp32_ms": round(ms_fp32, 2),
                    "fp32_top": EMOTION_CLASSES[int(np.argmax(p_fp32))],
                    "top1_match": same_top,
                    "max_abs_prob_diff": round(max_abs_diff, 5),
                }
            )
        report["samples"].append(entry)

    if compared > 0:
        report["fp32_vs_int8_top1_agreement"] = round(agreements / compared, 4)

    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
