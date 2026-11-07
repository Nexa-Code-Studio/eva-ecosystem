# Single Shared Workflow Contract: `eva-ecosystem` ↔ Discord Project Management Bot

> **Dokumen:** Kontrak Resmi Workflow Pengembangan, Kepemilikan State, Status Machine, dan Konvensi Antarmuka.  
> **Tanggal:** 2026-11-04  
> **Target Repositori:** `Nexa-Code-Studio/eva-ecosystem`  
> **Bot Terintegrasi:** `ekyaaa/dc-bot-project-management`

---

## 1. Prinsip Utama & Kepemilikan State

Untuk mencegah ambiguitas dan *split-brain*, setiap resource memiliki satu **Canonical Owner**:

| Komponen / Resource | Sumber Kebenaran (Canonical Owner) | Batasan & Aturan |
| :--- | :--- | :--- |
| **Definisi Task & Kriteria** | GitHub Issue | Acceptance criteria, deskripsi, kendala, dan diskusi teknis dicatat di issue. Dilarang membuat database task bayangan di Discord atau file JSON lokal repo. |
| **Status & Prioritas Pekerjaan** | GitHub Project v2 | Kolom single-select `Status` dan `Priority` pada Project v2 yang disepakati. Bot Discord membaca dan memperbarui status melalui API GraphQL ini. |
| **Bukti Implementasi** | Git Commits, PR, CI Suite | Perubahan status memerlukan bukti nyata (branch aktif, unit test lulus, PR review, merge). Dilarang membuat bukti palsu (*fabricated progress*). |
| **Identitas Perangkat / Agent** | `.agent/developer.local.json` | Konfigurasi per-mesin lokal (gitignored). Tidak disinkronkan melalui commit Git. |
| **Identitas Discord ↔ GitHub** | SQLite Storage pada Discord Bot | Ditautkan secara aman menggunakan OAuth 2.0 PKCE melalui perintah Discord `/account connect`. Dilarang menaruh mapping ID Discord di repo utama. |
| **Notifikasi & Interaksi Tim** | Discord Project Management Bot | Saluran komunikasi utama pengembang. Menerima webhook dari GitHub App dan memfasilitasi kueri status melalui slash commands. |

---

## 2. Kosakata Kanonikal: Status & Prioritas

### 2.1 Status Kanonikal
```text
Backlog  ───>  Ready  ───>  In Progress  ───>  In Review  ───>  Done
   │             │              │                 │
   └─────────────┴──────────────┴─────────────────┘
                         ▲
                         │ (dua arah)
                         ▼
                      Blocked
```

- **Backlog**: Pekerjaan tercatat namun belum siap dikerjakan (belum memiliki acceptance criteria jelas).
- **Ready**: Spesifikasi dan kriteria penerimaan telah lengkap; siap diambil oleh developer.
- **In Progress**: Sedang aktif dikerjakan oleh developer pada branch task terisolasi.
- **In Review**: Implementasi selesai, seluruh test lokal lulus, dan Pull Request terbuka siap direview.
- **Blocked**: Pekerjaan terhenti akibat kendala teknis atau dependensi eksternal. **Wajib menyertakan alasan kendala (minimal 3 karakter)**.
- **Done**: Pekerjaan telah selesai, PR telah di-merge ke branch utama (atau disetujui lead), dan CI lulus. **Done adalah status terminal** (tidak dapat dipindahkan kembali secara otomatis).

### 2.2 Transisi Status yang Diizinkan (*State Machine Matrix*)

| Dari Status | Target Status yang Diizinkan | Syarat & Bukti Minimum |
| :--- | :--- | :--- |
| `Backlog` | `Ready`, `In Progress`, `Blocked` | Kriteria penerimaan terisi (`Ready`) atau branch aktif dibuat (`In Progress`). |
| `Ready` | `In Progress`, `Backlog`, `Blocked` | Developer telah mengambil task dan branch aktif terverifikasi. |
| `In Progress` | `In Review`, `Ready`, `Blocked` | PR aktif dan bukti test lulus (`In Review`); atau alasan kendala (`Blocked`). |
| `In Review` | `Done`, `In Progress`, `Blocked` | PR ter-merge atau persetujuan developer tercatat (`Done`). |
| `Blocked` | `Backlog`, `Ready`, `In Progress`, `In Review` | Catatan resolusi kendala (*unblock note*). |
| `Done` | *(Tidak ada — Terminal)* | Status selesai permanen untuk siklus task tersebut. |

### 2.3 Tingkat Prioritas Kanonikal
1. **Urgent**: Kendala kritis/produksi, pemblokir sprint utama.
2. **High**: Fitur utama atau perbaikan penting sprint aktif.
3. **Medium**: Fitur standar atau peningkatan berkala (default).
4. **Low**: Penyempurnaan minor, refactor kosmetik, atau dokumentasi tambahan.

---

## 3. Konvensi Penamaan Branch & Worktree

Setiap pekerjaan pengkodean **wajib** menggunakan branch khusus dengan pola:

```text
{type}/{issue-number}-{short-kebab-slug}
```

### 3.1 Tipe yang Diizinkan
- `feat`: Penambahan fitur baru.
- `fix`: Perbaikan bug atau defek.
- `refactor`: Restrukturisasi kode tanpa mengubah fungsionalitas publik.
- `docs`: Pembaruan atau penambahan dokumentasi.
- `test`: Penambahan atau perbaikan test suite.
- `chore`: Konfigurasi tooling, dependensi, atau maintenance rutin.

### 3.2 Contoh Valid
- `feat/128-mood-tracker-ui`
- `fix/142-token-refresh-expiry`
- `refactor/155-notification-routing`

Branch pribadi berjangka panjang (seperti `dev/budi` atau `dev/ekya`) dilarang untuk pekerjaan task reguler guna menjaga keterlacakan integrasi.

---

## 4. Kebijakan Notifikasi: Single Production Sender

1. **Pengirim Tunggal:** Bot Discord (`ekyaaa/dc-bot-project-management`) adalah satu-satunya pengirim notifikasi produksi ke Discord.
2. **Jalur Event:**
   ```text
   Developer / Agent (Lokal)
             │
             ▼
        GitHub API (Issue, PR, Project v2)
             │
             ▼ Webhook Event Subscriptions
      GitHub App (Fastify Server pada Bot)
             │ (Verifikasi HMAC SHA-256 + Deduplikasi SQLite Outbox)
             ▼
     Discord Channel (#project-dev / notification channel)
   ```
3. **Gating Legacy Sender:** Workflow GitHub Actions lama (`.github/workflows/agentic-notifications.yml`) dinonaktifkan secara default menggunakan variabel `DISCORD_LEGACY_WEBHOOK_ENABLED=false` untuk mencegah duplikasi notifikasi.
4. **Karakteristik Router Bot Saat Ini:**
   - Push notifikasi otomatis dikirim saat: Issue dibuka/ditugaskan, PR meminta review/siap review/ditutup, dan CI gagal.
   - Perubahan status Project v2 atau komentar progres tersimpan di GitHub dan dapat dikueri on-demand via slash command bot (`/project status`, `/project issues`, `/issue view`), tanpa mengirim pesan push spam di kanal publik.
