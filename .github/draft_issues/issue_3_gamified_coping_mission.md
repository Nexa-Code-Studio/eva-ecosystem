# [Task]: Peningkatan Interaktivitas & Gamifikasi Coping Mission Harian

- **Assignee**: `@NathanaelGracedo`
- **Labels**: `task`, `mobile`, `gamification`, `ux`
- **Project**: Eva AI Development Board (#2)

---

### Goal & Scope

Meningkatkan modul Coping Mission / Rekomendasi Rutinitas Harian di Eva Mobile (`features/recommendations` dan komponen rutinitas di `HomeScreen`) dari yang sebelumnya berupa instruksi teks statis menjadi pengalaman yang **interaktif, menyenangkan, dan memiliki gamifikasi yang terasa nyata**.

Tujuannya adalah membangun kebiasaan pengguna dalam merawat kesehatan mentalnya melalui mekanisme gamifikasi yang terbukti efektif (*habit loop*: pemicu -> tindakan interaktif -> hadiah/reward kepuasan).

---

### Acceptance Criteria

- [ ] **Daily Mindful Streak System**:
  - Tampilkan indikator streak harian (misal: `🔥 3 Hari Berturut-turut`) di `HomeScreen` dan di kartu Coping Mission.
  - Perhitungan streak bertambah jika pengguna menyelesaikan minimal 1 misi coping dalam 24 jam.
- [ ] **Interactive Step-by-Step Guidance Card**:
  - Gantikan modal instruksi statis dengan alur langkah interaktif (*step-by-step wizard*):
    - **Latihan Nafas Terpandu**: Animasi lingkaran nafas (Inhale - Hold - Exhale) dengan timer mundur (contoh: teknik 4-7-8).
    - **Audio Chime / Voice Cue Opsional**: Opsi bunyi lembut saat pergantian fase nafas / langkah.
    - **Tactile / Haptic Feedback**: Getaran halus saat transisi antar-langkah atau saat menyelesaikan aktivitas.
- [ ] **Mindful XP & Level Progression**:
  - Setiap menyelesaikan misi, pengguna mendapatkan Mindful XP (misal: `+25 Mindful XP`).
  - Terdapat tingkatan level sederhana yang mencerminkan konsistensi (misal: *Pemula Tenang* -> *Penjelajah Pikiran* -> *Master Ketenangan*).
- [ ] **Celebration Micro-Interaction**:
  - Saat misi selesai, tampilkan animasi perayaan (efek partikel / konfeti halus dan pesan afirmasi positif yang hangat dari Eva).
- [ ] **Sinkronisasi Otomatis ke Backend**:
  - Misi yang selesai tetap mencatat bukti penyelesaian ke endpoint backend aktif `POST /api/v1/recommendations/{id}/complete` untuk disimpan di tabel database `UserActivityCompletion`.

---

### Technical Notes & Architecture

- **Clean Architecture & Riverpod**:
  - Simpan state gamifikasi (streak, XP harian) menggunakan Riverpod StateNotifier di `features/recommendations/presentation/providers/`.
  - Pisahkan komponen animasi dan timer ke widget mandiri di `features/recommendations/presentation/widgets/` untuk menjaga kohesi kode.
- **Backend Paritas**:
  - Model backend `CopingActivity` dan `UserActivityCompletion` sudah tersedia di `apps/backend/api/app/models/coping_activity.py`.
  - Pemanggilan `recommendationRepositoryProvider.markAsCompleted(id)` otomatis mencatat riwayat ke backend.
- **Micro-Interactions**:
  - Gunakan `HapticFeedback.lightImpact()` dari `package:flutter/services.dart` untuk sentuhan haptic tanpa menambah package berat.

---

### Dependencies & Blockers

- Tidak ada blocking dependensi. Fitur ini dapat langsung dikembangkan secara independen di frontend Flutter `apps/eva_mobile`.
- Jika memerlukan penyesuaian payload rekomendasi dari AI, komunikasikan langsung di issue ini.

---

### Definition of Done

- [ ] Unit & widget tests implemented and passing untuk alur interaktif rekomendasi
- [ ] Branch conforms to `feat/{issue}-gamified-coping-mission`
- [ ] Pull request includes test evidence dan lolos review
