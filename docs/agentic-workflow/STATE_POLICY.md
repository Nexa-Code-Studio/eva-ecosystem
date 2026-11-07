# Kebijakan Status dan Bukti (State Policy)

Dokumen ini mendefinisikan aturan transisi status tugas, bukti verifikasi yang diperlukan (*evidence*), penanganan kondisi crash, serta jaminan idempotensi.

---

## 1. Matriks Transisi & Bukti Wajib

Setiap perpindahan status wajib memiliki bukti nyata yang dapat diverifikasi oleh script `sync-state.py`:

```
[Backlog]
   │  (Bukti: Acceptance Criteria disetujui)
   ▼
[Ready]
   │  (Bukti: Task Branch checked out)
   ▼
[In Progress] ◄────────┐
   │       │          │
   │       │ (Blocker)│ (Unblock Note)
   │       ▼          │
   │   [Blocked] ─────┘
   │
   │  (Bukti: PR URL + Passing Test Suite)
   ▼
[In Review]
   │  (Bukti: PR Merged / Developer Sign-off)
   ▼
[Done]
```

### Tabel Rincian Bukti

| Dari | Menuju | Syarat Bukti Minimum | Dampak Kegagalan |
| :--- | :--- | :--- | :--- |
| `Backlog` | `Ready` | Dokumentasi *acceptance criteria* jelas | Ditolak; tetap di `Backlog` |
| `Ready` | `In Progress` | Cabang kerja `{type}/{issue}-{slug}` telah dibuat dan aktif | Ditolak; tidak dapat memulai implementasi |
| `In Progress` | `Blocked` | Keterangan blocker spesifik (min. 5 karakter) | Ditolak |
| `Blocked` | `In Progress` | Catatan resolusi unblock | Ditolak |
| `In Progress` | `In Review` | URL Pull Request aktif dan ringkasan bukti pengujian | Ditolak; PR harus dibuka terlebih dahulu |
| `In Review` | `Done` | Verifikasi bahwa PR telah di-merge atau persetujuan developer manusia | Ditolak; tes lulus saja **bukan** bukti tugas `Done` |

---

## 2. Perilaku saat Agent Mati Mendadak (Agent Crash)

- **Tidak Ada Transisi Otomatis**: Jika proses agent mati mendadak, koneksi internet terputus, atau terminal ditutup, status tugas **tetap berada pada status terakhir yang tercatat**.
- **Tidak Otomatis Selesai**: Kegagalan proses tidak akan pernah menandai tugas sebagai `Done` atau menutup issue.
- **Melanjutkan Sesi**: Saat developer membuka sesi baru, jalankan `python3 scripts/agentic/tasks.py` untuk membaca kembali status nyata dari Git dan GitHub, bukan mengandalkan asumsi percakapan sebelumnya.

---

## 3. Idempotensi Sinkronisasi

Script `sync-state.py` dirancang sepenuhnya **idempotent**:
- Jika status saat ini sama dengan status target, script tidak melakukan mutasi remote dan tidak mengirim komentar berulang (*no-op*).
- Informasi status lokal dicatat di `.agent/task-state.json`.

---

## 4. Otoritas Perubahan (Siapa Boleh Mengubah Apa)

- **Developer**: Berhak mengubah seluruh status kapan saja.
- **AI Agent**: Boleh menjalankan transisi `In Progress`, `Blocked`, dan `In Review` **hanya bila bukti valid tersedia**. AI agent dilarang menandai tugas `Done` tanpa bukti merge nyata atau persetujuan eksplisit.
