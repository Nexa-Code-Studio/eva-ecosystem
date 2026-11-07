# Integration Discovery Report: Agentic Workflow `eva-ecosystem` ↔ Discord Project Management Bot

> **Dokumen:** Hasil Discovery, Forensik Git/Filesystem, dan Pemetaan Kontrak Integrasi.  
> **Tanggal:** 2026-11-04  
> **Status:** DISCOVERED & PRESERVED (Phase A Complete)

---

## 1. Ringkasan Eksekutif

Pemeriksaan sistem telah dilakukan pada repositori lokal `eva-ecosystem` dan repositori bot referensi `ekyaaa/dc-bot-project-management`.

1. **Perubahan Lokal Belum Ter-push:** Seluruh fondasi agentic workflow (`.agent/`, `.agents/skills/`, `scripts/agentic/`, `tests/agentic/`, `docs/agentic-workflow/`, `.github/workflows/agentic-*`) berada dalam status **untracked / modified lokal** pada branch `main` (commit dasar `c40a9a9`). Tidak ada file lokal yang dihapus atau di-reset; seluruh implementasi lokal dipertahankan seutuhnya.
2. **Repositori Bot Referensi:** Repositori `ekyaaa/dc-bot-project-management` (commit `7ae19d8`) telah di-inspeksi secara *read-only*. Bot dibangun dengan TypeScript + Fastify + Discord.js + SQLite outbox + GitHub App OAuth.
3. **Temuan Kunci Arsitektur & Gaps:**
   - **Single Sender Policy:** Bot Discord yang sudah ada bertindak sebagai *single source of notification delivery* melalui webhook GitHub App. Workflow lama `.github/workflows/agentic-notifications.yml` (yang menggunakan direct incoming webhook) harus dinonaktifkan secara default (`DISCORD_LEGACY_WEBHOOK_ENABLED != true`) agar tidak menimbulkan notifikasi ganda.
   - **Router Bot Event Limitations:** Bot saat ini hanya merespons event:
     - `issues`: `opened`, `assigned`, `reopened`, `closed`
     - `pull_request`: `review_requested`, `ready_for_review`, `closed`
     - `workflow_run` / `check_suite`: `completed` (hanya `failure` atau `timed_out`)
     - Event `projects_v2_item` dan `issue_comment` **tidak diproses** oleh `NotificationService` bot untuk pesan push Discord. Perubahan status Project tetap tercatat di GitHub dan dapat dilihat melalui slash command `/project status` atau `/issue view`.
   - **Project Owner Binding Gap pada Bot:** Pada `src/infrastructure/github/GitHubService.ts`, bot menggunakan variabel tunggal `GITHUB_OWNER` untuk repositori dan Project v2. Jika Project v2 dimiliki oleh user (misal `@ekyaaa`) sementara repositori berada di bawah organisasi (`Nexa-Code-Studio`), kueri GraphQL bot akan gagal menemukan Project. Patch kompatibilitas disediakan pada `docs/agentic-workflow/BOT_COMPATIBILITY_PATCH.md`.
   - **Environment Lokal Developer:** Tool `gh` (GitHub CLI) belum terpasang di environment sistem (`Nobara Linux 44`). Script agentic lokal harus beroperasi secara *offline-first* (`LOCAL_READY`), dan mendegradasi sinkronisasi remote secara elegan (`PENDING_CONFIGURATION`).

---

## 2. Status Baseline & Inventaris `eva-ecosystem` (Main Repo)

### 2.1 Git Status & Branch State
- **Root Directory:** `/home/mashupsoat/Project/eva-ecosystem`
- **Current Branch:** `main` (sinkron dengan `origin/main` di commit `c40a9a9`)
- **Remote Origin:** `git@github.com:Nexa-Code-Studio/eva-ecosystem.git`
- **Worktree List:** 1 worktree aktif di `/home/mashupsoat/Project/eva-ecosystem`

### 2.2 Inventaris File Agentic Workflow Lokal
| Direktori / File | Status Git | Keterangan |
| :--- | :--- | :--- |
| `.agent/developer.schema.json` | Untracked | Schema JSON v1 identitas workstation |
| `.agent/developer.example.json` | Untracked | Contoh template identitas non-sensitif |
| `.agent/developer.local.json` | Gitignored | File identitas per-mesin (belum digenerate) |
| `.agents/AGENTS.md` | Modified | Aturan optimasi token & kebijakan koordinasi |
| `.agents/hooks.json` | Untracked | Konfigurasi hook Antigravity CLI (`SessionStart`, `PreInvocation`) |
| `.agents/rules/` | Untracked / Tracked | Aturan arsitektur & konstrain agentic |
| `.agents/skills/` | Untracked / Tracked | Skill modular (`developer-onboarding`, `task-startup`, `project-state-sync`, `pr-preparation`) |
| `scripts/agentic/` | Untracked | Utilitas Python (`doctor.py`, `bootstrap.py`, `tasks.py`, `start_task.py`, `sync_state.py`, `prepare_pr.py`, dll.) |
| `tests/agentic/` | Untracked | Test suite unit (37 tests, Python standard library) |
| `.github/workflows/agentic-ci.yml` | Untracked | CI untuk memverifikasi script agentic |
| `.github/workflows/agentic-notifications.yml` | Untracked | Legacy webhook notification workflow |

---

## 3. Hasil Analisis Repositori Bot (`ekyaaa/dc-bot-project-management`)

### 3.1 Ringkasan Komponen Bot
- **Runtime:** Node.js (v20+), TypeScript, Fastify HTTP server, SQLite (better-sqlite3) dengan WAL mode.
- **Autentikasi GitHub:**
  - Bot ➔ GitHub: GitHub App JWT & Installation Access Token (via `@octokit/auth-app`).
  - Developer ➔ GitHub: OAuth 2.0 PKCE melalui slash command `/account connect` (menyimpan pemetaan `discord_user_id` ↔ numeric `github_user_id` di SQLite dengan enkripsi AES-256-GCM).
- **Ingesti Webhook:**
  - Endpoint: `POST /webhooks/github`.
  - Verifikasi: HMAC SHA-256 (`crypto.timingSafeEqual`) dari raw request buffer.
  - Outbox: SQLite outbox queue dengan deduplikasi berbasis `X-GitHub-Delivery` (`INSERT OR IGNORE`).
  - Worker: Polling periodik (setiap 3 detik) untuk memproses batch pesan keluar.

### 3.2 Pemetaan Status & Prioritas
```text
Canonical Status:
  Backlog ➔ Ready ➔ In Progress ➔ In Review ➔ Done
  (Blocked bersifat bidirectional dengan Backlog, Ready, In Progress, In Review)
  (Done bersifat terminal)

Canonical Priority:
  Urgent | High | Medium | Low
```

### 3.3 Matriks Rute Webhook Bot (`NotificationService.ts`)
| GitHub Event | Action / Condition | Diproses ke Discord? | Tipe Embed / Konten | Catatan |
| :--- | :--- | :---: | :--- | :--- |
| `issues` | `opened` | **Ya** | `buildIssueWebhookEmbed` | Embed info issue baru |
| `issues` | `assigned` | **Ya** | `buildIssueWebhookEmbed` | Mention `<@discord_id>` jika terhubung via OAuth; unlinked mendapat sanitized text `@login` |
| `issues` | `reopened` / `closed` | **Ya** | `buildIssueWebhookEmbed` | Embed status issue |
| `pull_request` | `review_requested` | **Ya** | `buildPullRequestWebhookEmbed` | Mention `<@discord_id>` ke requested reviewer terdaftar |
| `pull_request` | `ready_for_review` | **Ya** | `buildPullRequestWebhookEmbed` | Embed PR siap review |
| `pull_request` | `closed` (merged/closed) | **Ya** | `buildPullRequestWebhookEmbed` | Embed PR merged atau closed |
| `workflow_run` | `completed` (`failure` / `timed_out`) | **Ya** | `buildCiFailureWebhookEmbed` | Embed kegagalan CI |
| `check_suite` | `completed` (`failure` / `timed_out`) | **Ya** | `buildCiFailureWebhookEmbed` | Embed kegagalan check suite |
| `projects_v2_item` | Any action (`edited`, `created`) | **TIDAK** | - | **GAP:** `routeEvent` mengembalikan `shouldSend: false` |
| `issue_comment` | `created` | **TIDAK** | - | **GAP:** `routeEvent` mengembalikan `shouldSend: false` |

---

## 4. Matriks Perbandingan: Desain Awal vs Arsitektur Integrasi Bot

| Aspek | Desain Awal (`eva-ecosystem` local) | Arsitektur Integrasi Bot Eksisting | Solusi Rekonsiliasi |
| :--- | :--- | :--- | :--- |
| **Pengirim Notifikasi** | GitHub Actions ➔ Incoming Webhook URL | GitHub App Webhooks ➔ Bot Fastify ➔ Discord Bot Client | Matikan workflow Actions lama (`DISCORD_LEGACY_WEBHOOK_ENABLED=false`). Bot menjadi pengirim tunggal. |
| **Pemetaan Akun** | `DISCORD_MENTION_MAP` di GitHub Secrets | OAuth 2.0 PKCE via slash command `/account connect` di Discord | Developer cukup menjalankan `/account connect` sekali. Hapus kebutuhan mapping JSON di GitHub Secrets. |
| **Status Machine** | `sync-state.py` mengecek bukti parsial | `StatusTransitionPolicy` di bot menegakkan state machine ketat | Perbarui `sync_state.py` agar mencerminkan transisi kanonikal bot dan aturan blocker (min 3 karakter). |
| **Sinkronisasi State** | Mengharapkan notifikasi webhook langsung untuk setiap comment | Bot hanya mem-push event issue/PR/CI; status Project dicek via command on-demand | Berikan informasi jelas pada developer bahwa update status Project tersedia di `/project status` dan tidak memicu push spam di Discord. |
| **Kredensial Runtime** | Secrets di GitHub Actions | `.env` server VPS tempat bot berjalan | Pisahkan konfigurasi: main repo hanya butuh identitas developer dan link repo; secrets runtime bot tetap di VPS. |

---

## 5. Rencana Perubahan Minimal (Surgical & Non-Destructive)

1. **Harden `scripts/agentic/sync_state.py`:**
   - Adopsi `ALLOWED_STATUS_TRANSITIONS` yang identik dengan `StatusTransitionPolicy` bot.
   - Larang transisi keluar dari `Done` (terminal).
   - Validasi alasan blocker minimal 3 karakter saat target status `Blocked`.
   - Berikan peringatan informatif bahwa pembaruan status Project v2 tidak memicu notifikasi push otomatis di bot saat ini.
2. **Harden `scripts/agentic/doctor.py`:**
   - Pisahkan indikator `LOCAL_READY` (mesin lokal siap untuk coding & branching) dan `REMOTE_READY` (akses GitHub API & Project v2 siap).
   - Berikan panduan instalasi `gh` yang tepat untuk distro Linux yang terdeteksi (`Nobara Linux` ➔ `sudo dnf install gh`).
3. **Gating Legacy Webhook Workflow:**
   - Tambahkan syarat `vars.DISCORD_LEGACY_WEBHOOK_ENABLED == 'true'` pada `.github/workflows/agentic-notifications.yml'`.
4. **Sinkronisasi Reusable Skills & Rules:**
   - Tambahkan rule `github-coordination.md`.
   - Pastikan skill `inspect-project-tasks`, `start-task`, `sync-project-state`, `prepare-pr`, dan `developer-onboarding` tersedia dan sesuai spesifikasi Antigravity CLI.
5. **Dokumentasi Kontrak & Panduan:**
   - Buat `GITHUB_BOT_CONTRACT.md`, `DEVELOPER_ONBOARDING.md`, `DAILY_AGENT_WORKFLOW.md`, `GITHUB_PROJECT_BINDING.md`, `BOT_ADMIN_CHECKLIST.md`, `INTEGRATION_TEST_REPORT.md`, dan `BOT_COMPATIBILITY_PATCH.md`.
