# [Task]: Sinkronisasi Integrasi API Eva Mobile & Hardening AI Voice Call

- **Assignee**: `@ekyaaa`
- **Labels**: `task`, `mobile`, `backend`, `voice-call`
- **Project**: Eva AI Development Board (#2)

---

### Goal & Scope

Menangani seluruh fungsionalitas **AI Voice Call (Telepon AI)** serta integrasi data dan penyelarasan endpoint antara `apps/eva_mobile` dan `apps/backend` agar Eva Mobile dapat beroperasi secara penuh dan stabil dalam mode Live API (`USE_MOCK_DATA=false`).

Tugas ini sepenuhnya dipegang oleh Ekya, mencakup optimalisasi WebSocket telepon AI, perbaikan update kontak darurat (PUT), implementasi endpoint update profil, penyimpanan preferensi pengguna, input obrolan teks interaktif, dan pembersihan file legacy.

---

### Acceptance Criteria

#### 1. AI Voice Call (Telepon AI)
- [ ] **Kestabilan Koneksi WebSocket Telepon**:
  - `VoiceCallWsClient` terhubung dengan andal ke endpoint WebSocket backend `/api/v1/call/ws/{session_id}` dengan handling reconnection saat sinyal fluktuatif.
- [ ] **Aliran Audio Setengah-Dupleks (ElevenLabs TTS)**:
  - Streaming audio ElevenLabs dari backend diputar tanpa lag atau stuttering via `ai_audio_playback_service.dart`.
  - Event `interrupt` bekerja responsif memotong pemutaran suara AI ketika pengguna menyela bicara (*barge-in / VAD*).
- [ ] **Pencatatan Sesi Panggilan & Ringkasan**:
  - Durasi panggilan (`sendEndCall`) dan transkrip pesan tersimpan rapi di backend dan langsung dapat dimuat di `VoiceSessionDetailScreen` via `GET /api/v1/conversations/{id}`.
- [ ] **Pembersihan REST Endpoint Dummy Telepon**:
  - Hapus method REST HTTP yang tidak terpakai di `RemoteVoiceCallDataSource` (`/voice/calls/start`, `/voice/calls/{id}/end`, `/voice/calls/{id}/summary`).

#### 2. Data Alignment & Core Features
- [ ] **Fix Update Emergency Contact (PUT)**:
  - Tambahkan method `updateEmergencyContact` pada `AuthDataSource` & `AuthRepository`.
  - Hubungkan dengan endpoint backend `PUT /api/v1/users/emergency-contacts/{contact_id}` saat edit kontak di `emergency_contacts_screen.dart` (mencegah penambahan data ganda karena memanggil POST).
- [ ] **Endpoint Update Profil Pengguna (PUT /users/me)**:
  - Buat endpoint FastAPI `PUT /api/v1/users/me` (atau `PATCH /api/v1/users/me`) untuk memperbarui nama, nomor telepon, dan gender di database PostgreSQL.
  - Hubungkan form modal `_showEditProfileModal` di `profile_screen.dart` agar perubahan tersimpan ke backend.
- [ ] **Sinkronisasi Pengaturan Pengguna (User Settings)**:
  - Simpan preferensi suara Eva, kecepatan bicara, dan mode interaksi ke backend agar tidak hanya tertinggal di `SharedPreferences`.
- [ ] **Input Chat Teks Interaktif pada `AiConversationScreen`**:
  - Tambahkan kolom input teks (`TextField`), tombol kirim, dan status bubble di `AiConversationScreen`.
  - Hubungkan dengan `chatRepository.sendMessage()` (`POST /api/v1/conversations/{id}/messages`).
- [ ] **Pembersihan File Legacy**:
  - Hapus 18 file screen lama di `apps/eva_mobile/lib/screens/` yang sudah digantikan oleh arsitektur feature modul di `apps/eva_mobile/lib/features/`.
  - Pastikan audit paritas lulus melalui `python3 scripts/agentic/check_mobile_backend_contract.py`.

---

### Technical Notes & Architecture

- **Clean Architecture Mobile**: Ikuti pola Clean Architecture di `apps/eva_mobile/lib/features/voice_call/`, `features/auth/`, dan `features/chat/`.
- **FastAPI Clean Architecture**: Ikuti Thin Router pattern (3-5 baris) di `apps/backend/api/app/api/routes/user.py`, `call.py`, dan `auth.py`.
- **Contract Verification Tool**: Jalankan `python3 scripts/agentic/check_mobile_backend_contract.py` untuk memastikan seluruh kontrak pemanggilan API valid.

---

### Dependencies & Blockers

- Tidak ada blocking dependensi. Berjalan paralel dengan pengerjaan Video Call (Okta & Nisa) dan Gamifikasi Coping (Nathanael).

---

### Definition of Done

- [ ] Panggilan suara AI berjalan lancar via WebSocket dengan latency interupsi responsif
- [ ] Edit profil dan update kontak darurat tersimpan di PostgreSQL backend
- [ ] Pesan teks dapat dikirim dan dibalas secara interaktif di chat screen
- [ ] `check_mobile_backend_contract.py` pass tanpa error
- [ ] Pull request lolos review
