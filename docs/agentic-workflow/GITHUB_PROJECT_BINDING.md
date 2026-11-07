# GitHub Project v2 Binding & Configuration Guide

> **Dokumen:** Panduan Pengikatan Repositori `eva-ecosystem`, GitHub Projects v2, dan Runtime Discord Bot.  
> **Sasaran:** Memastikan keselarasan metadata antara GitHub CLI lokal dan GitHub App pada Discord Bot.

---

## 1. Pemisahan Jalur Autentikasi

Integrasi ini menerapkan pemisahan kredensial yang ketat:

```text
┌─────────────────────────────────┐       ┌─────────────────────────────────┐
│     Developer / Agent (Lokal)   │       │     Discord Bot (Server / VPS)  │
├─────────────────────────────────┤       ├─────────────────────────────────┤
│ • GitHub CLI ('gh')             │       │ • GitHub App Private Key (.pem) │
│ • Token Personal / SSH Key      │       │ • GitHub App Installation ID    │
│ • Hak akses sesuai membership   │       │ • Scopes: Issues (RW),          │
│ • Diikat di .agent/developer.*  │       │   Projects (RW), PRs (Read)     │
└─────────────────────────────────┘       └─────────────────────────────────┘
```

Tidak ada token GitHub App atau private key PEM yang disimpan di repositori lokal atau dibagikan ke workstation pengembang.

---

## 2. Pengikatan Project v2: Organisasi vs Pengguna

### Struktur Kepemilikan
- **Repositori Target:** `Nexa-Code-Studio/eva-ecosystem` (Dimiliki oleh Organisasi `Nexa-Code-Studio`).
- **Target Project v2:**
  - **Kasus Ideal:** Project v2 dibuat di tingkat Organisasi (`https://github.com/orgs/Nexa-Code-Studio/projects/<NUMBER>`).
  - **Kasus Khusus (Personal Board):** Jika Project v2 dibuat di bawah akun user (`https://github.com/users/<USERNAME>/projects/<NUMBER>`).

> [!WARNING]
> Bot Discord (`dc-bot-project-management`) secara bawaan menggunakan variabel `GITHUB_OWNER` untuk repositori dan Project. Jika Project berada di bawah akun pengguna (misal `@ekyaaa`) sementara repositori berada di bawah organisasi (`Nexa-Code-Studio`), bot memerlukan patch dukungan `GITHUB_PROJECT_OWNER`. Lihat [BOT_COMPATIBILITY_PATCH.md](file:///home/mashupsoat/Project/eva-ecosystem/docs/agentic-workflow/BOT_COMPATIBILITY_PATCH.md).

---

## 3. Konfigurasi Binding di Identitas Lokal (`.agent/developer.local.json`)

Pada mesin developer lokal, nomor Project v2 dicatat pada bagian `project`:

```json
{
  "schema_version": 1,
  "developer": {
    "display_name": "Alexander Agung",
    "github_username": "ekyaaa"
  },
  "workspace": {
    "machine_label": "dev-nobara"
  },
  "project": {
    "project_number": 1,
    "project_owner": "Nexa-Code-Studio",
    "project_title": "Eva AI Development Board",
    "status_field": "Status",
    "priority_field": "Priority"
  }
}
```

---

## 4. Konfigurasi Binding di Runtime Discord Bot (`.env`)

Pada server VPS tempat bot berjalan:

```ini
# Repositori
GITHUB_OWNER=Nexa-Code-Studio
GITHUB_REPOSITORY=eva-ecosystem

# Nomor Project v2
GITHUB_PROJECT_NUMBER=1

# Opsi Pemilik Project Khusus (Bila patch kompatibilitas diaktifkan)
# GITHUB_PROJECT_OWNER=ekyaaa
```

---

## 5. Menemukan Metadata Project v2 Menggunakan GitHub CLI

Ketika `gh` telah terpasang dan terautentikasi:

### A. Melihat Daftar Project di Organisasi
```bash
gh project list --owner Nexa-Code-Studio
```

### B. Melihat Kolom Status dan Nilai Opsi
```bash
gh project field-list <PROJECT_NUMBER> --owner Nexa-Code-Studio
```

Output akan menampilkan field ID dan opsi status:
- `Status`: `Backlog`, `Ready`, `In Progress`, `In Review`, `Blocked`, `Done`
- `Priority`: `Urgent`, `High`, `Medium`, `Low`
