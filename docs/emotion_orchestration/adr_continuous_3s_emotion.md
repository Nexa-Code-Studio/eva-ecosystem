# ADR-143: Continuous 3-Second Speech Emotion Inference, 30–60s Temporal Aggregation & Serverless Isolation

- **Status:** Accepted (Feature-flagged `OFF` by default pending clinical validation & #96 privacy gates)
- **Issue:** [#143](https://github.com/Nexa-Code-Studio/eva-ecosystem/issues/143)
- **Related:** [#96 — Luna Local Selective LTM (SQLCipher) & Consent-Based Clinical Sharing](https://github.com/Nexa-Code-Studio/eva-ecosystem/issues/96)
- **Audit Baseline:** `origin/main` @ `d2a201922039822635f270146223f4d4b03e5d5b`

---

## 1. Context & Problem

Psikolog menghendaki observasi suara pengguna berdurasi **30–60 detik** untuk konteks afektif percakapan EVA/Luna. Audit terhadap implementasi existing menemukan enam bottleneck utama:

1. **Blocking Full-Turn Inference:** `CallSessionManager._commit_turn_and_start_ai` (`apps/backend/api/app/services/call/session_manager.py`) menggabungkan seluruh audio turn dari `SessionAudioBuffer` lalu menunggu `MLEmotionDetectorService.predict_message_emotion(...)` selesai **sebelum** menjalankan `AIOrchestrator` dan streaming LLM/TTS.
2. **Sync Inference di Event Loop & Risiko Format Audio:** `MLEmotionDetectorService.predict_message_emotion` (`apps/backend/api/app/services/emotion/ml_detector.py`) menulis raw PCM bytes langsung ke file `.wav` sementara tanpa header WAV, lalu memanggil `EmotionService.predict()` secara sinkron di dalam `async def`.
3. **Unbounded Buffer & Provenance Mismatch:** `SessionAudioBuffer` (`stream_buffer.py`) tidak memiliki batas ukuran/TTL. Metadata di `ml_detector.py`, `orchestrator.py`, dan `domain_types.py` mengklaim `emotion2vec_plus_large`, padahal default aktual `packages/ai/services/emotion_service.py` adalah `iic/emotion2vec_plus_base`.
4. **Skor Sintetis saat Data Kosong:** `_send_session_summary_event` (`session_manager.py`) dan `aggregate_session_emotions` (`ml_detector.py`) mengembalikan persentase default buatan (`neutral: 0.70–0.85`, `stress: 0.10`) seolah-olah hasil pengukuran.
5. **Keterbatasan Kapasitas VPS Tunggal:** 100 pengguna berbicara kontinu menghasilkan 33,33 req/s (16,67 req/s pada 50% speech duty cycle) untuk segmen 3 detik, jauh di atas throughput VPS tunggal (~1,39–1,63 req/s Base ONNX INT8).
6. **Ketidakselarasan Privasi (#96):** `CallPersistenceService.save_message` dan `MLEmotionDetectorService.save_emotion_to_db` masih menulis ke PostgreSQL (`messages`, `emotion_analyses`), dan `unregister_session` memicu `sync_today_diary` / `sync_today_dass` tanpa memeriksa `privacy_mode`.

---

## 2. Actual Codebase Audit (Mobile → Backend → AI)

### 2.1 Audio Capture & Transport
- **Android Native:** `apps/eva_mobile/android/app/src/main/kotlin/com/example/eva_mobile/audio/AudioCaptureEngine.kt` menangkap audio dengan `AudioRecord` (`MediaRecorder.AudioSource.MIC`, tanpa hardware AEC) pada format kanonik **16.000 Hz, mono (`CHANNEL_IN_MONO`), signed 16-bit PCM little-endian (`ENCODING_PCM_16BIT`)**, chunk `4.800 bytes` (150 ms).
- **Android Bridge:** `MainActivity.kt` melewati `startAudioCapture` pada Android Emulator (`result.success(false)`). Pada perangkat fisik, `AudioCaptureEngine` berjalan paralel dengan `speech_to_text` (`pipeOutputStream = null`), sehingga bukan physical single-mic capture.
- **iOS:** `apps/eva_mobile/ios/Runner/AppDelegate.swift` belum memiliki handler `com.eva.single_audio/*`; iOS berjalan pada jalur STT Flutter dengan fallback text-only (`isRawAudioStreamSupported = false`).
- **Flutter Gating & WS:** `ai_call_controller.dart` hanya mengirim binary PCM frame ke `VoiceCallWsClient.sendAudioChunk` saat `state.callState == CallState.listening && !state.isMuted`. `voice_call_ws_client.dart` sudah mengirim `?privacy_mode=local_private` serta protokol #96 (`client_context_v1`, `session_finalize_v1`, `session_artifacts_ack_v1`).

### 2.2 Backend & AI
- `apps/backend/api/app/api/routes/call.py`: `/api/v1/call/ws/{session_id}` delegasi ke `call_session_manager.handle_connection`.
- `packages/ai/services/risk_assessment_service.py`: Terverifikasi **100% independen** dari `emotion_result` (hanya memakai `user_text`, `symptom_result`, `dass_scores`).
- `apps/backend/workers/app/tasks/emotion_task.py`: ARQ task menerima `audio_path` lokal; tidak dipakai pada jalur live voice call dan tidak boleh menerima audio privat.

---

## 3. Architectural Decisions

1. **Canonical Audio & Sample-Count Segmentation (Backend):**
   - Canonical format: mono, signed PCM16 LE, `16.000 Hz` (`1 segmen 3 detik = 48.000 samples = 96.000 bytes`).
   - Segmentasi dilakukan di backend (`SessionAudioSegmenter`) berdasarkan jumlah sample valid dengan byte alignment 2-byte, multi-emit untuk frame besar, bounded buffer cap, RMS speech-activity check (memisahkan silence murni tanpa concatenate lintas jeda panjang), dan flush remainder pada boundary (turn commit, mute, barge-in, capture restart, end-call) dengan batas tail minimum (`EMOTION_MIN_TAIL_DURATION_MS=750`, configurable `500–1000 ms`).
2. **Non-Blocking Bounded Fair Dispatcher (RAM-Only):**
   - `BoundedEmotionDispatcher` menggunakan in-memory fair per-session queues (`put_nowait`), batas global & per-session in-flight, stale deadline, idempotency `segment_id`, dan `generation_token` untuk menolak late result pasca disconnect/finalize.
   - Zero durable queue (tidak menggunakan Redis/ARQ, DB, object store, atau temp disk file untuk audio privat).
3. **Isolated ONNX INT8 Microservice (`apps/backend/emotion_service/`):**
   - FastAPI + single `onnxruntime.InferenceSession` per proses container, thread limits terkonfigurasi, verifikasi SHA-256 artefak model, preprocessing in-memory PCM16→float32, endpoint `POST /v1/emotions/predict`, `GET /health`, `GET /ready`.
   - Autentikasi service-to-service privat (Cloud Run IAM/OIDC dengan audience valid), tanpa PII pada request.
   - Target deployment: Google Cloud Run (Jakarta `asia-southeast2`, request-based billing, `min-instances=0`, `concurrency=1`, `2 vCPU`, `1 GiB RAM`).
4. **Temporal Aggregation (30–60s Rolling Window):**
   - Baseline duration-weighted mean untuk segmen sukses saja: `p_window(c) = sum(w_i * p_i(c)) / sum(w_i)` dengan `w_i = valid_speech_ms`.
   - `coverage = speech_analyzed_ms / speech_received_ms`.
   - Status eksplisit: `unavailable | partial | ready | stale`. Tidak ada data → `unavailable` / `null` (nol neutral/stress sintetis).
   - Default window `30.000 ms` (configurable hingga `60.000 ms`), staleness TTL default `180.000 ms` (configurable, menunggu konfirmasi psikolog).
5. **Orchestrator, Safety & TTS Guard:**
   - `AIOrchestrator.prepare_turn` menerima `temporal_emotion` dan `allow_sync_audio_fallback=False` pada jalur voice call.
   - Prompt menyajikan sinyal akustik sebagai observasi tentatif; konflik transkrip vs audio mengutamakan self-report.
   - `RiskAssessmentService` & `SafetyGate` tetap 100% independen dari kesiapan emosi.
   - `resolve_dynamic_voice_style` hanya melakukan override suara bila status akustik valid & kuat (`status == "ready"` atau `partial` dengan coverage cukup & `segment_count >= 2`, `source == "audio_temporal"`).
6. **Privacy Alignment (#96) & Feature Flag:**
   - Default `EMOTION_STREAMING_ENABLED=False`.
   - Mode `local_private` & `incognito`: zero durable DB write (`messages`, `emotion_analyses`, `diary_entries`, `dass_assessments`).
   - Mode `incognito`: fail-closed untuk jalur audio cloud (`EMOTION_ALLOW_INCOGNITO_CLOUD_AUDIO=False`).

---

## 4. Sequence Flow (Current vs Target)

### Current (Blocking)
```text
Mobile --(binary PCM)--> CallSessionManager --> SessionAudioBuffer (unbounded)
Mobile --(turn commit)--> CallSessionManager --(AWAIT sync predict_message_emotion)--> Disk .wav --> FunASR/fallback
                                             --(blocked!)--> AIOrchestrator --> LLM/TTS
                                             --(bg task)--> PostgreSQL (messages + emotion_analyses)
```

### Target (Non-Blocking & Isolated)
```text
Mobile --(binary PCM)--> CallSessionManager --(put_nowait)--> SessionAudioSegmenter (3s / 96KB)
                                                                 |
                                                     BoundedEmotionDispatcher (RAM-only)
                                                                 | (Private HTTP + IAM/OIDC, No PII)
                                                       Cloud Run: ONNX INT8
                                                                 | (9-class scores JSON)
                                                   SessionTemporalEmotionAggregator (30-60s)
                                                                 |
Mobile --(turn commit)--> CallSessionManager --(immutable snapshot, non-blocking)--> AIOrchestrator + Independent Safety --> LLM/TTS
Mobile --(finalize/disconnect)--> Bounded Drain --> Session Emotion Artifact (compat #96) --> Zero-Retention RAM Cleanup
```

---

## 5. Clinical Validation Gate & Merge Coordination (#96)

- **Clinical Gate:** Segmentasi 3 detik menghilangkan interaksi self-attention lintas segmen; tidak boleh diklaim setara secara klinis dengan audio kontinu 30–60 detik sebelum validasi dan sign-off psikolog.
- **Merge Conflict Strategy (#96):** Seluruh logika baru dipisahkan ke modul kohesif (`audio_segmenter.py`, `emotion_dispatcher.py`, `temporal_emotion_aggregator.py`, `emotion_coordinator.py`) sehingga `session_manager.py` dan `persistence.py` hanya memuat hook tipis dan guard privasi bersama.
