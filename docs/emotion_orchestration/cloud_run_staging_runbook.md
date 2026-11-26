# Cloud Run Staging Deployment, Benchmark & Rollback Runbook (Issue #143)

> **PENTING:** Jangan menjalankan deployment Cloud Run berbayar sebelum persetujuan GCP project, IAM service account, dan plafon budget diberikan secara eksplisit. Feature flag `EMOTION_STREAMING_ENABLED` tetap `false` sampai seluruh privacy gate (#96), load test staging, dan clinical validation sign-off psikolog terpenuhi.

---

## 1. Artefak Model & Verifikasi Pra-Build

1. Siapkan file ONNX INT8 `emotion2vec_plus_base_int8.onnx` yang tervalidasi (sumber `https://huggingface.co/emotion2vec/emotion2vec_plus_base`, lisensi & checksum tercatat).
2. Verifikasi checksum SHA-256, schema tensor, mapping 9 kelas resmi, dan parity FP32 vs INT8:
   ```bash
   python3 apps/backend/emotion_service/scripts/export_and_verify_onnx.py \
     --int8-model /path/to/emotion2vec_plus_base_int8.onnx \
     --fp32-model /path/to/emotion2vec_plus_base_fp32.onnx \
     --wav-dir tests/test_emotion
   ```
3. Catat nilai `int8_sha256` untuk di-pin pada environment variable `EMOTION_MODEL_SHA256`.

---

## 2. Build & Local Verification (Docker Compose)

```bash
# Menjalankan stack lokal + emotion_service (mode mock default di dev)
docker compose --profile emotion up --build emotion_service

# Uji health & readiness
curl -sf http://localhost:8890/health
curl -sf http://localhost:8890/ready
```

Untuk menguji dengan model ONNX INT8 nyata di lokal, mount file model ke `/models/emotion2vec_plus_base_int8.onnx` dan set `EMOTION_ENGINE_BACKEND=onnxruntime`.

---

## 3. Baseline Konfigurasi Cloud Run Staging (Private Service-to-Service)

- **Region:** `asia-southeast2` (Jakarta, bila tersedia/diizinkan)
- **Billing:** Request-based (`--cpu-throttling`)
- **Scaling:** `--min-instances=0`, `--concurrency=1`, `--max-instances=<sesuai budget & load test>` *(catatan: 20 instances tidak cukup untuk 100 user 100% speech bila throughput setara VPS ~1,39 req/s; proyeksi awal ~35 instances full / ~18 instances pada 50% duty cycle)*
- **Resources:** `--cpu=2`, `--memory=1Gi` *(uji juga 1 vCPU & 2 GiB di staging untuk perbandingan peak RSS vs biaya)*
- **Ingress & Auth:** `--no-allow-unauthenticated` (private Cloud Run IAM/OIDC; berikan peran `roles/run.invoker` **hanya** ke service account VPS backend). Dilarang keras menempatkan kredensial di Flutter atau git repo.
- **Env Vars Container:**
  - `APP_ENV=production`
  - `EMOTION_ENGINE_BACKEND=onnxruntime`
  - `EMOTION_SERVICE_AUTH_MODE=gcp_oidc`
  - `EMOTION_SERVICE_AUDIENCE=https://<staging-service-url>`
  - `EMOTION_MODEL_PATH=/models/emotion2vec_plus_base_int8.onnx`
  - `EMOTION_MODEL_SHA256=<pinned-sha256>`
  - `EMOTION_MODEL_REVISION=<pinned-revision>`
  - `ORT_INTRA_OP_THREADS=2`
  - `ORT_INTER_OP_THREADS=1`

---

## 4. Protokol Benchmark Staging (Actual vs Projection)

1. Uji panjang segmen `3 / 5 / 10` detik dan audio utuh `30 / 60` detik pada runtime/hardware identik.
2. Jalankan load test konkurensi `1 / 10 / 30 / 50 / 100` user, duty cycle `30% / 50% / 100%`, serta sustained workload 30–60 menit:
   ```bash
   python3 apps/backend/emotion_service/scripts/benchmark_staging.py \
     --url https://<staging-service-url> \
     --token "$(gcloud auth print-identity-token --audiences=https://<staging-service-url>)" \
     --users 1,10,30,50,100 \
     --segment-s 3 \
     --duty-cycle 0.5 \
     --duration-s 1800
   ```
3. Catat secara terpisah (jangan campurkan dengan proyeksi):
   - Warm E2E latency P50/P95/P99 (hipotesis target awal P95 ≤ 1.500 ms), cold start, error/drop rate, coverage.
   - Delta TTFT & TTFA pada endpoint WebSocket `/api/v1/call/ws/{session_id}` terhadap baseline `EMOTION_STREAMING_ENABLED=false`.
   - CPU, RSS peak, container startup time, dan actual Cloud Run billing report.

---

## 5. Observability Non-PII & Alerting

Hanya log/ekspor metrik operasional non-PII (dilarang keras mencatat audio, transkrip, skor personal per user, atau token):
- `dispatcher.queue_depth`, `dispatcher.inflight_current`, `dropped_queue_full`, `dropped_deadline_exceeded`, `discarded_stale_session`
- `emotion_http_latency_ms` (p50/p95/p99), circuit breaker open events, Cloud Run 429/5xx, OOM restarts, cold start count, dan budget alert GCP.

---

## 6. Prosedur Rollback Aman (Zero Local Heavy Inference)

Jika terjadi lonjakan biaya, latensi, error rate, atau temuan privasi/kualitas:
1. Set `EMOTION_STREAMING_ENABLED=false` pada environment VPS API dan restart service `api`.
2. Pastikan `EMOTION_PROVIDER=mock` atau jalur audio lokal **tidak** diaktifkan di VPS (container API tetap lightweight tanpa `torch`/`funasr`).
3. Panggilan suara kembali ke jalur STT + LLM + TTS text-only secara instan tanpa gangguan percakapan maupun safety gate.
