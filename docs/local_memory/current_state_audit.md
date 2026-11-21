# Current State Audit: Peta Aliran Read/Write Data Sensitif Server & Client

> **Dokumen Audit P0**: Refaktor Luna Local Selective Long-Term Memory (SQLCipher) & Consent-Based Clinical Sharing  
> **Repository**: https://github.com/Nexa-Code-Studio/eva-ecosystem  
> **Tanggal**: 21 November 2026  
> **Status**: Completed (P0 Baseline Audit)

---

## 1. Ringkasan Eksekutif & Temuan Kritis

Audit ini memetakan seluruh titik baca (*read*) dan tulis (*write*) data percakapan emosional, transkrip suara, asesmen psikometrik (DASS-21), jurnal harian, dan kredensial/token pada server (`apps/backend`), modul AI (`packages/ai`), serta aplikasi Flutter (`apps/eva_mobile` dan `apps/eva_counselor_mobile`).

### Temuan Kritis (*Critical Privacy & Security Findings*):
1. **Server-Side Cross-Session Recall Otomatis**: Setiap panggilan suara baru via WebSocket secara otomatis membaca 10 pesan terakhir dari 5 sesi terdahulu dan skor DASS-21 terbaru dari PostgreSQL, lalu menginjeksinya ke prompt sistem (`apps/backend/api/app/services/call/persistence.py`).
2. **Penulisan Pesan & Jurnal Permanen Pasca-Sesi**: Saat panggilan berakhir (`end_call` / socket disconnect), background task `sync_today_diary` dan `sync_today_dass` mengeksekusi LLM dan menyimpan transkrip, ringkasan, dan skor DASS langsung ke PostgreSQL tanpa persetujuan granular lokal.
3. **Prompt Marker Parsing**: `AIOrchestrator.prepare_turn` mengekstrak `persisted_memory` dengan mem-parsing marker string `"[Memori Percakapan Terdahulu Pengguna]:"`, bukan melalui parameter terstruktur yang aman dari prompt injection.
4. **Cacat Privacy-by-Default pada Booking Sheet**: `_shareAiChatHistory` di `BookingConsultationSheet` (`apps/eva_mobile`) bernilai `true` secara default, membagikan data pasien secara broad kepada psikolog.
5. **Tombol "Hapus Memori" Hanyalah Mock**: Dialog reset memori di `SettingsScreen` hanya menampilkan pesan `AppSnackBar` sukses tanpa melakukan mutasi atau penghapusan data fisik apapun.
6. **Ekspos Token JWT**: `TokenStorage` menyimpan JWT di `SharedPreferences` plaintext, dan `VoiceCallWsClient` menyertakan token dalam query URL WebSocket yang tercetak pada `debugPrint`.

---

## 2. Peta Aliran Sensitif Server (`apps/backend` & `packages/ai`)

| Komponen / Class | Fungsi / Endpoint | Tipe Operasi | Data yang Disentuh | Dampak Privasi & Target Migrasi |
|---|---|---|---|---|
| `CallPersistenceService` | `load_conversation_history` | **READ & WRITE** | `conversations`, `messages`, `dass_assessments` (PostgreSQL) | Membaca riwayat lampau & membuat baris `Conversation` baru. **Wajib dimatikan** pada mode `local_private`. |
| `CallPersistenceService` | `save_message` | **WRITE** | `messages`, `message_emotions` | Menyimpan setiap giliran suara dan emosi ke database. **Wajib dibypass/no-op** pada mode `local_private`. |
| `CallPersistenceService` | `update_session_end` | **WRITE** | `conversations.last_message_at` | Memperbarui timestamp akhir sesi. Pada mode `local_private`, hanya simpan metadata non-klinis jika sesi tercatat. |
| `CallPersistenceService` | `sync_today_diary` | **READ & WRITE** | `conversations`, `messages`, `conversation_summaries`, `diary_entries` | Mensintesis jurnal kumulatif dari transkrip server dan menyimpannya ke DB. **Wajib diganti** dengan artefak sesi yang dikirim ke Flutter client. |
| `CallPersistenceService` | `sync_today_dass` | **READ & WRITE** | `conversations`, `dass_assessments` | Mengekstrak DASS-21 otomatis dari transkrip dan menyimpan ke DB. **Wajib dipisahkan** dari LTM dan tidak disimpan otomatis di DB server. |
| `CallSessionManager` | `handle_connection` | **WS LIFECYCLE** | WebSocket `/api/v1/call/ws/{session_id}` | Memanggil `load_conversation_history` sebelum `call_connected`. **Wajib diubah** agar menunggu `client_context_v1` dari Flutter. |
| `CallSessionManager` | `unregister_session` | **LIFECYCLE HOOK** | Async tasks `_sync_today_diary`, `_sync_today_dass` | Memicu background write ke PostgreSQL saat socket putus. **Wajib diganti** dengan alur finalisasi berbasis ACK sebelum socket ditutup. |
| `SummaryStreamService` | `stream_summary` (`GET /conversations/{id}/summary/stream`) | **READ & WRITE** | `conversations`, `messages`, `conversation_summaries` | Streaming SSE dan menyimpan `ConversationSummary` ke PostgreSQL. **Wajib diisolasi** dari penyimpanan permanen server. |
| `DiaryGeneratorService` | `generate_today_diary` | **READ & WRITE** | `conversations`, `messages`, `diary_entries` | Query pesan hari ini dan panggil DeepSeek. **Wajib dipisahkan** menjadi fungsi sintesis murni (`synthesize_session_artifacts`) tanpa dependensi DB. |
| `AIOrchestrator` | `prepare_turn` | **MEMORY INGESTION** | System Prompt Layer 2 (`persisted_memory`) | Mem-parsing string marker `"[Memori Percakapan Terdahulu Pengguna]:"`. **Wajib di-refactor** menjadi `structured_persisted_context`. |
| `Memory` (Model) | `apps/backend/api/app/models/memory.py` | **PLANNED SCHEMA** | Tabel `memories` | Jalur server-side vector memory. **Dilarang diaktifkan** untuk memori personal pengguna; gunakan SQLite lokal. |
| `extract_memory_task` | `apps/backend/workers/app/tasks/summarization.py` | **PLANNED WORKER** | Placeholder ekstraksi memori ARQ | **Dilarang diaktifkan** untuk LTM personal. |

---

## 3. Peta Aliran Sensitif Client (`apps/eva_mobile` & `apps/eva_counselor_mobile`)

| File / Komponen | Method / Widget | Tipe Operasi | Data yang Disentuh | Dampak Privasi & Target Migrasi |
|---|---|---|---|---|
| `token_storage.dart` | `saveToken`, `getToken` | **LOCAL STORAGE** | `SharedPreferences` (`jwt_token`) | Plaintext JWT storage. Wajib diaudit agar kunci database terenkripsi (DEK) tidak diletakkan di SharedPreferences. |
| `voice_call_ws_client.dart` | `connect` | **NETWORK / LOG** | WebSocket Query URL (`?token=...`), `debugPrint` | Token terlihat di URL dan tercetak di console log. Wajib sanitasi logging URL dan migrasi auth ke protokol pesan awal jika memungkinkan. |
| `booking_consultation_sheet.dart` | `_shareAiChatHistory` | **CONSENT / UI** | State checkbox, payload booking | **Default `true`**. Cacat privasi. Wajib diubah menjadi **default `false`** dengan granular modal untuk memilih hanya keluhan & diagnosis profesional. |
| `settings_screen.dart` | `_showResetMemoryDialog` | **UI ACTION** | Dialog konfirmasi hapus memori | Hanya menampilkan snackbar sukses tanpa aksi hapus. Wajib dihubungkan ke `LocalMemoryRepository.clearAllMemories()` di SQLCipher. |
| `settings_screen.dart` | `_incognitoSessionMode` | **PREFERENCE** | `SharedPreferences` (`settings_incognito`) | Hanya tersimpan lokal sebagai bool, tidak dikirim ke backend. Wajib dihubungkan ke handshake WS `privacy_mode=incognito`. |
| `remote_diary_datasource.dart` | `getDiaries`, `createDiary`, dll. | **NETWORK DATA** | Endpoint REST `/diaries` | Bergantung penuh pada cloud server. Wajib digantikan oleh `LocalDiaryDataSource` (SQLCipher) sebagai sumber utama. |
| `patient_detail_consent_screen.dart` (`counselor_mobile`) | `_buildDassSection`, `_buildJournalSection` | **CLINICAL UI** | Data skrining DASS dan jurnal pasien | Menampilkan seluruh rekam medis lama pasien. Wajib dibatasi hanya pada paket data klinis yang spesifik disetujui (`complaints` & `professional_diagnoses`). |

---

## 4. Evaluasi API REST & WebSocket Terkait

1. **WebSocket Telepon AI (`/api/v1/call/ws/{session_id}`)**:
   - *Status Saat Ini*: Tidak memiliki negosiasi mode privasi. Otomatis membaca dan menulis ke DB.
   - *Rencana V1*: Tambahkan payload `client_context_v1` (bounded 3-5 item) dan protokol finalisasi `session_finalize_v1` -> `session_artifacts_v1` -> `session_artifacts_ack_v1`.
2. **Endpoint Jurnal (`/api/v1/diaries`)**:
   - *Status Saat Ini*: Server adalah primary store untuk `DiaryEntry`.
   - *Rencana V1*: Pada mode `local_private`, jurnal disimpan di SQLCipher lokal. Endpoint `/diaries` hanya digunakan untuk legacy sync/one-time import berizin.
3. **Endpoint Consent Pasien (`/api/v1/patients/{id}/consent/{counselor_id}`)**:
   - *Status Saat Ini*: Model `PatientConsent` hanya berupa boolean granted/revoked tanpa granular scope.
   - *Rencana V1*: Dukung granular payload scope (`complaints` dan `professional_diagnoses`) yang terikat dengan `booking_id`.

---

## 5. Kesimpulan Audit P0

Seluruh jalur penulisan dan pembacaan sensitif telah teridentifikasi dengan jelas. Tidak ada fitur LTM personal yang boleh ditulis ke PostgreSQL atau Qdrant server pada mode `local_private`. Implementasi penyimpanan SQLite terenkripsi (SQLCipher) pada Flutter menjadi prasyarat mutlak sebelum fitur memori dan jurnal lokal diaktifkan.
