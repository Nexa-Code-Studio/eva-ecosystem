# [Task]: Implementasi & Integrasi Real-Time Video Call Konsultasi Psikolog

- **Assignees**: `@ekyaaa` (Lead Integrasi), `@Oktavian19` (Backend PIC), `@KhoirotunNisa25` (Mobile PIC)
- **Labels**: `task`, `mobile`, `backend`, `care`, `video-call`
- **Project**: Eva AI Development Board (#2)

---

### Goal & Scope

Menggantikan antarmuka mock video call saat ini di `PsychologistVideoCallScreen` dengan implementasi **Video Call Real-Time yang sesungguhnya** untuk sesi konsultasi antara pengguna dengan psikolog / konselor berlisensi.

Kolaborasi tugas dibagi secara spesifik:
1. **Okta (@Oktavian19 - Backend)**: Menyediakan infrastruktur signaling / session token (WebRTC / LiveKit / Agora SDK backend), endpoint pembuatan room sesi konsultasi, dan webhook status panggilan.
2. **Nisa (@KhoirotunNisa25 - Mobile)**: Mengintegrasikan client video call di Flutter (rendering video lokal & remote, kontrol mic/kamera/speaker, transisi UI) menggantikan timer mock di `psychologist_video_call_screen.dart`.
3. **Ekya (@ekyaaa - Lead Integrator)**: Mengoordinasikan integrasi alur end-to-end mulai dari jadwal booking konsultasi, inisiasi sesi video call, hingga tampilan ringkasan hasil konsultasi (*ConsultationResultBottomSheet*).

---

### Acceptance Criteria

#### Backend Workstream (PIC: @Oktavian19)
- [ ] **Room & Token Generation API**:
  - Endpoint `POST /api/v1/care/sessions/{session_id}/video-token` (atau protokol signaling WebRTC/LiveKit/Agora yang disepakati).
  - Validasi hak akses: hanya user pemilik sesi dan psikolog yang dapat memperoleh token room.
- [ ] **Call Session State Management**:
  - Endpoint update status panggilan (`active`, `completed`, `missed`) dan pencatatan durasi aktual sesi konsultasi.
- [ ] **Webhook / Event Handling**:
  - Penanganan event disconnect / user left room untuk mengakhiri sesi secara aman.

#### Mobile Workstream (PIC: @KhoirotunNisa25)
- [ ] **Integrasi Client Video Call di Flutter**:
  - Tambahkan plugin client (misal: `livekit_client` atau `agora_rtc_engine`) pada `apps/eva_mobile`.
  - Refactor `psychologist_video_call_screen.dart` agar merender **feed video kamera lokal** (self preview) dan **feed video psikolog remote**.
- [ ] **Kontrol Media Interaktif**:
  - Tombol mute/unmute mikrofon, toggle kamera on/off, switch kamera depan/belakang, dan toggle speaker audio.
- [ ] **Transisi State & Penanganan Jaringan**:
  - Tampilkan indikator status koneksi (Connecting, Reconnecting, Call Ended).
  - Saat panggilan berakhir, otomatis navigasi ke `ConsultationResultBottomSheet` untuk menampilkan catatan saran psikolog.

#### End-to-End Flow (PIC: @ekyaaa)
- [ ] Memastikan transisi alur dari `ConsultationScheduleScreen` -> Masuk ke Room Video Call -> Selesai Konsultasi berjalan mulus tanpa error.

---

### Technical Notes & Architecture

- **Mobile Screen**: [apps/eva_mobile/lib/features/care/presentation/screens/psychologist_video_call_screen.dart](file:///home/mashupsoat/Project/eva-ecosystem/apps/eva_mobile/lib/features/care/presentation/screens/psychologist_video_call_screen.dart).
- **Consultation Session Model**: [consultation_session_entity.dart](file:///home/mashupsoat/Project/eva-ecosystem/apps/eva_mobile/lib/features/care/domain/entities/consultation_session_entity.dart).
- **Backend Service Path**: Tempatkan router di `apps/backend/api/app/api/routes/care.py` dan business logic di `app/services/care/`.

---

### Dependencies & Blockers

- Ekya, Okta, dan Nisa berkoordinasi langsung pada thread issue ini mengenai pemilihan provider WebRTC (LiveKit vs Agora) dan format token response.

---

### Definition of Done

- [ ] Video feed dua arah (pengguna dan psikolog) tampil jernih dengan audio sinkron
- [ ] Kontrol mic, kamera, dan toggle switch kamera depan/belakang berfungsi normal
- [ ] Sesi tercatat selesai di backend dan menampilkan sheet hasil konsultasi
- [ ] Pull request lolos review dan pengujian perangkat fisik
