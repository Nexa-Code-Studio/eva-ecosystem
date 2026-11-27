# EVA Ecosystem Multi-Instance Stress Test Suite

Suite pengujian beban **multi-instance** (`multiprocessing` + `asyncio`) untuk mengukur kapasitas konkurensi VPS (`docker-compose.prod.yml`) pada jalur **AI Pipelines** dan **WebRTC Video Call Signaling** sambil memantau grafik **`btop`** di terminal VPS.

### Dependensi Client
Runner membutuhkan `aiohttp` dan `websockets` (bisa langsung dijalankan tanpa install global menggunakan `uv run`):
```bash
uv run --with aiohttp --with websockets python3 tests/load_test/run_stress_test.py --help
```

---

## 1. Persiapan VPS Sebelum Pengujian (Anti-Quota Burn)

Saat menguji kapasitas infrastruktur (`eva_api`, `eva_worker`, `eva_mcp`, `eva_postgres`, `eva_redis`, `eva_qdrant`) tanpa membakar kuota API LLM/STT/TTS eksternal, aktifkan mode `mock` di `.env` VPS sementara waktu:

```env
LLM_PROVIDER=mock
STT_PROVIDER=mock
TTS_PROVIDER=mock
```

Lalu restart stack produksi (`docker compose -f docker-compose.prod.yml up -d`). Kembalikan ke provider produksi setelah pengujian selesai.

---

## 2. Skenario yang Tersedia

1. **`--scenario ai`**:
   - Auto-login / auto-register akun uji (`stress_test_<idx>@gmail.com`, atau pakai `--shared-auth` agar semua virtual user memakai 1 akun `stress_test@gmail.com` tanpa memenuhi tabel `users` produksi)
   - `GET /api/v1/conversations`, `GET /api/v1/conversations/today`
   - `POST /api/v1/conversations/{id}/messages`, `GET /api/v1/conversations/{id}/summary/stream` (SSE)
   - `WS /api/v1/call/ws/{session_id}` + `POST /api/v1/call/synthesize`
2. **`--scenario video`**:
   - Pasangan Patient + Counselor memanggil `POST /api/v1/care/sessions/{id}/video-token`
   - Koneksi WebSocket simultan ke `WS /api/v1/care/ws/{session_id}` (burst `offer`, `answer`, `ice_candidate`)
   - `POST /api/v1/care/sessions/{id}/status`
3. **`--scenario mixed`**:
   - Gabungan beban `ai` dan `video` secara paralel.

---

## 3. Contoh Perintah Bertahap (Sambil Melihat `btop` di VPS)

Buka terminal VPS dan jalankan `btop`, lalu jalankan tier beban berikut dari mesin Anda:

### Tier 1 — Baseline (10 Users, 2 Worker Processes)
```bash
python3 tests/load_test/run_stress_test.py \
  --target-url https://api.domain-vps-anda.com \
  --scenario ai \
  --users 10 \
  --instances 2 \
  --ramp-up 5 \
  --ai-mode mock
```

### Tier 2 — Medium Load (25 Users, 4 Worker Processes)
```bash
python3 tests/load_test/run_stress_test.py \
  --target-url https://api.domain-vps-anda.com \
  --scenario ai \
  --users 25 \
  --instances 4 \
  --ramp-up 10 \
  --ai-mode mock
```

### Tier 3 — High Load (50–100+ Users)
```bash
python3 tests/load_test/run_stress_test.py \
  --target-url https://api.domain-vps-anda.com \
  --scenario mixed \
  --users 100 \
  --instances 8 \
  --ramp-up 20 \
  --ai-mode mock \
  --credentials-file tests/load_test/video_sessions.example.json
```

### Mode Real-Case Suara Asli (`tests/test_emotion/*.wav`) dengan Durasi Dinamis
Opsi `--ai-mode live` otomatis membaca file WAV dari `tests/test_emotion/` (mengonversi format `48kHz stereo` menjadi PCM `16kHz mono` sesuai standar STT & Emotion service), lalu memotong atau mengulang aliran suara tepat selama `--voice-duration` detik:

```bash
.venv/bin/python tests/load_test/run_stress_test.py \
  --target-url https://eva.nexacode.dev \
  --scenario ai \
  --users 10 \
  --instances 2 \
  --ai-mode live \
  --audio-dir tests/test_emotion \
  --voice-duration 15 \
  --audio-pace realtime \
  --shared-auth
```

- Ubah `--voice-duration 15` ke durasi berapa pun (mis. `8`, `33`, atau `90` detik).
- Tambahkan `--audio-sample tests/test_emotion/combined_speech_33s.wav` jika ingin memakai satu file tertentu saja.
- Tambahkan `--audio-pace fast` untuk mengirim seluruh chunk PCM tanpa jeda `100ms` (menguji *backpressure* server).
- Tambahkan `--stt-fallback` jika ingin mengirim `stt.final_segment` cadangan setelah audio selesai.

---

## 4. Format `--credentials-file` untuk Skenario `video` / `mixed`

Buat salinan JSON berisi `session_id` konsultasi yang valid beserta kredensial pasien dan psikolog:

```json
{
  "video_sessions": [
    {
      "session_id": "00000000-0000-0000-0000-000000000001",
      "patient_email": "patient1@eva.test",
      "patient_password": "Password123!",
      "counselor_email": "counselor1@eva.test",
      "counselor_password": "Password123!"
    }
  ]
}
```

---

## 5. Output & Cara Membaca Bottleneck bersama `btop`

Setiap eksekusi otomatis mencetak ringkasan ke terminal dan menyimpan laporan `.json` + `.md` ke `tests/load_test/reports/`:
- **CPU `eva_api` mentok 100% pada 2 core**: pertimbangkan menaikkan `--workers` pada `uvicorn` di `docker-compose.prod.yml`.
- **Latency p95/p99 naik tajam saat CPU rendah**: indikasi saturasi connection pool PostgreSQL (`pool_size` / `max_overflow` di `apps/backend/api/app/db/session.py`) atau antrean `eva_worker` / `eva_mcp`.
- **WS drop rate > 0%**: periksa batas open file descriptor (`ulimit -n`), proxy timeout Nginx/Caddy, atau koneksi Redis Pub/Sub.
