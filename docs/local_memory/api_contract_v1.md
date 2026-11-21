# API & WebSocket Contract Specification (v1)

> **Dokumen Kontrak API P0**: Refaktor Luna Local Selective Long-Term Memory (SQLCipher) & Consent-Based Clinical Sharing  
> **Repository**: https://github.com/Nexa-Code-Studio/eva-ecosystem  
> **Tanggal**: 21 November 2026  
> **Status**: Completed (P0 Baseline Contract Specification)

---

## 1. Siklus Hidup Sesi WebSocket Telepon AI (`/api/v1/call/ws/{session_id}`)

### 1.1 Diagram Urutan Aliran Sesi (Sequence Flow)

```text
Flutter Mobile (Client)                               FastAPI Backend (Server)
      │                                                         │
      │ 1. Connect WebSocket /api/v1/call/ws/{session_id}       │
      ├────────────────────────────────────────────────────────>│
      │    (Auth verified, Mode: local_private / incognito)     │
      │                                                         │
      │ 2. Event: call_connected                                │
      │<────────────────────────────────────────────────────────┤
      │    { type: "call_connected", context_supported: true }  │
      │                                                         │
      │ 3. (Opt-in) Event: client_context_v1 (Max 5 items)      │
      ├────────────────────────────────────────────────────────>│
      │    { type: "client_context_v1", items: [...] }          │
      │                                                         │
      │ 4. Event: context_ack_v1                                │
      │<────────────────────────────────────────────────────────┤
      │    { type: "context_ack_v1", accepted_count: 2 }        │
      │                                                         │
      │ ═══════════════════════════════════════════════════════ │
      │          Normal Speech / STT / LLM / TTS Turns          │
      │ ═══════════════════════════════════════════════════════ │
      │                                                         │
      │ 5. User Ends Call -> Event: session_finalize_v1         │
      ├────────────────────────────────────────────────────────>│
      │    { type: "session_finalize_v1", request_id: "..." }   │
      │                                                         │
      │ 6. Event: session_artifacts_v1 (In-Memory Synthesis)    │
      │<────────────────────────────────────────────────────────┤
      │    { type: "session_artifacts_v1", summary, ... }       │
      │                                                         │
      │ 7. Atomic Commit to Local SQLCipher                     │
      │    Event: session_artifacts_ack_v1                     │
      ├────────────────────────────────────────────────────────>│
      │    { type: "session_artifacts_ack_v1", status: "saved" }│
      │                                                         │
      │ 8. Event: session_finalized_v1 & Disconnect             │
      │<────────────────────────────────────────────────────────┤
      │                                                         │
```

---

## 2. Spesifikasi Payload WebSocket

### 2.1 Handshake: `call_connected` (Server ➔ Client)
```json
{
  "type": "call_connected",
  "session_id": "c1f7b8a2-3d4e-4f5a-8b9c-0d1e2f3a4b5c",
  "protocol_version": 1,
  "privacy_mode_active": "local_private",
  "context_supported": true,
  "message": "Connected to Eva AI Phone Service (Local-Memory Protocol v1)"
}
```

### 2.2 Injeksi Konteks: `client_context_v1` (Client ➔ Server)
- **Constraint**: Maksimal 5 item, maksimal 500 karakter per item, total payload `< 4KB`.
- **Allowed Categories**: `psychological_complaint`, `emotional_trigger`, `coping_strategy`, `professional_diagnosis`, `social_support`, `interaction_preference`.
```json
{
  "type": "client_context_v1",
  "protocol_version": 1,
  "client_session_id": "c1f7b8a2-3d4e-4f5a-8b9c-0d1e2f3a4b5c",
  "context_request_id": "req-98765432-1234",
  "privacy_mode": "local_private",
  "context_scope": "conversation_personalization",
  "items": [
    {
      "id": "mem-01",
      "category": "coping_strategy",
      "text": "Jalan pagi di taman membantu meredakan rasa cemas",
      "status": "active"
    },
    {
      "id": "mem-02",
      "category": "interaction_preference",
      "text": "Lebih menyukai didengarkan dahulu sebelum diberikan saran langkah praktis",
      "status": "active"
    }
  ]
}
```

### 2.3 Konfirmasi Konteks: `context_ack_v1` (Server ➔ Client)
```json
{
  "type": "context_ack_v1",
  "context_request_id": "req-98765432-1234",
  "accepted_count": 2,
  "rejected_count": 0,
  "rejection_reasons": []
}
```

### 2.4 Finalisasi Sesi: `session_finalize_v1` (Client ➔ Server)
```json
{
  "type": "session_finalize_v1",
  "client_session_id": "c1f7b8a2-3d4e-4f5a-8b9c-0d1e2f3a4b5c",
  "request_id": "fin-11223344",
  "duration_seconds": 345,
  "request_memory_candidates": true
}
```

### 2.5 Pengiriman Artefak: `session_artifacts_v1` (Server ➔ Client)
```json
{
  "type": "session_artifacts_v1",
  "request_id": "fin-11223344",
  "session_summary": "Pengguna mendiskusikan rasa gugup menghadapi wawancara kerja dan mempraktikkan teknik pernapasan 4-7-8.",
  "journal_delta": {
    "title": "Kecemasan Wawancara Kerja & Teknik Relaksasi",
    "summary": "Membahas persiapan mental sebelum wawancara penting dan komitmen untuk berjalan pagi.",
    "content": "Sesi berfokus pada validasi perasaan tegang sebelum interview. Pengguna merasa lebih tenang setelah latihan napas terarah.",
    "mood_tag": "Netral & Tenang 😌",
    "mood_emoji": "😌",
    "emotional_level": 3,
    "ai_insight": "Tingkat ketegangan dapat diantisipasi dengan rutinitas grounding sebelum acara penting.",
    "emotional_reflection": "Ketenangan berasal dari persiapan yang realistis, bukan kesempurnaan.",
    "important_events": ["Latihan pernapasan 4-7-8"]
  },
  "memory_candidates": [
    {
      "candidate_id": "cand-556677",
      "category": "psychological_complaint",
      "fact_text": "Merasa cemas dan detak jantung berdebar kencang saat hendak berbicara di forum/wawancara",
      "source_type": "user_reported",
      "source_excerpt": "Jantungku rasanya berdebar banget kalau mau interview",
      "source_verification": "unverified",
      "should_require_confirmation": true
    }
  ]
}
```

### 2.6 Konfirmasi Artefak: `session_artifacts_ack_v1` (Client ➔ Server)
```json
{
  "type": "session_artifacts_ack_v1",
  "request_id": "fin-11223344",
  "status": "committed_locally",
  "client_committed_at": "2026-11-21T17:00:00+07:00"
}
```

### 2.7 Penutupan Akhir: `session_finalized_v1` (Server ➔ Client)
```json
{
  "type": "session_finalized_v1",
  "request_id": "fin-11223344",
  "status": "closed"
}
```

---

## 3. Spesifikasi Endpoint REST Berbagi Data Klinis ke Psikolog

### 3.1 Endpoint Upload Consent & Paket Klinis
- **Method / Path**: `POST /api/v1/care/bookings/{booking_id}/clinical-share`
- **Auth**: Bearer JWT Pasien
- **Headers**: `Idempotency-Key: <UUID>`

#### Request Body:
```json
{
  "version": 1,
  "psychologist_id": "550e8400-e29b-41d4-a716-446655440000",
  "consent_version": "clinical-share-v1",
  "items": {
    "complaints": [
      {
        "text": "Sulit tidur dan cemas berkepanjangan menjelang ujian/tugas akhir",
        "source": "user_confirmed",
        "last_confirmed_at": "2026-11-20"
      }
    ],
    "professional_diagnoses": [
      {
        "diagnosis_name": "Generalized Anxiety Disorder (GAD)",
        "source_label": "self_reported",
        "notes": "Pengguna menyatakan pernah didiagnosis oleh psikiater RS pada tahun 2024"
      }
    ]
  }
}
```

#### Response (201 Created):
```json
{
  "share_receipt_id": "rec-99887766-5544",
  "booking_id": "b1a2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d",
  "psychologist_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "authorized",
  "authorized_categories": ["complaints", "professional_diagnoses"],
  "expires_at": "2026-11-22T23:59:59+07:00",
  "created_at": "2026-11-21T17:05:00+07:00"
}
```

### 3.2 Endpoint Revokasi Consent Pasien
- **Method / Path**: `DELETE /api/v1/care/bookings/{booking_id}/clinical-share`
- **Auth**: Bearer JWT Pasien
- **Response (200 OK)**:
```json
{
  "share_receipt_id": "rec-99887766-5544",
  "status": "revoked",
  "revoked_at": "2026-11-21T17:10:00+07:00",
  "message": "Clinical data sharing has been revoked. The psychologist will no longer have access to this payload."
}
```

### 3.3 Endpoint Pembacaan Paket oleh Psikolog
- **Method / Path**: `GET /api/v1/care/sessions/{session_id}/shared-clinical-bundle`
- **Auth**: Bearer JWT Psikolog
- **Security Check**: Memverifikasi bahwa psikolog yang meminta adalah psikolog yang ditugaskan pada sesi konsultasi tersebut dan status consent pasien masih `authorized` (belum di-revoke/expired). Jika tidak valid, mengembalikan `403 Forbidden`.

---

## 4. Penanganan Kesalahan (*Error Codes & Boundaries*)

| Kode Error | Keterangan | Tindakan Client / Server |
|---|---|---|
| `CONTEXT_PAYLOAD_TOO_LARGE` | Jumlah item > 5 atau total byte > 4KB | Server menolak paket konteks; sesi tetap berjalan tanpa konteks memori (*fail-closed*). |
| `UNSUPPORTED_MEMORY_CATEGORY` | Enum kategori tidak terdaftar dalam 6 taksonomi resmi | Server menolak item terkait pada `context_ack_v1`. |
| `INCOGNITO_MODE_ENFORCED` | Klien berada pada mode Incognito | Seluruh penyimpanan dinonaktifkan di kedua sisi. |
| `CONSENT_RECIPIENT_MISMATCH` | `psychologist_id` tidak sesuai dengan jadwal booking | Permintaan berbagi ditolak dengan HTTP 400 Bad Request. |
| `CLINICAL_SHARE_REVOKED` | Pasien telah mencabut persetujuan berbagi | Akses psikolog ditutup seketika dengan HTTP 403 Forbidden. |
| `FINALIZATION_TIMEOUT` | Klien terputus sebelum mengirimkan `session_artifacts_ack_v1` | Server membuang memori sementara sesuai TTL; tidak melakukan penulisan fallback ke PostgreSQL. Klien mempertahankan draf lokal yang sudah diterima. |

---

## 5. Strategi Kompatibilitas (*Backward Compatibility*)

- **Client Lama (v0) yang Menghubungi Backend**: Jika client tidak mengirimkan `client_context_v1`, server mengenali sebagai sesi legacy dan tidak menginjeksi memori.
- **Booking Lama**: Flag boolean legacy `share_ai_chat_history=true` dinilai sebagai **tidak memiliki izin v1 yang spesifik**. Backend tidak mengekspos jurnal atau riwayat transkrip ke psikolog tanpa persetujuan eksplisit paket v1.
