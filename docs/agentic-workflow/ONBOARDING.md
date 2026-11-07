# Panduan Onboarding Developer

Dokumen ini menjelaskan langkah-langkah inisialisasi lingkungan kerja developer pada workstation baru atau worktree baru agar siap berkolaborasi dengan AI coding agent (Antigravity CLI).

---

## 1. Prasyarat Lingkungan

Pastikan perangkat Anda telah terpasang:
- **Git** (versi >= 2.30): `git --version`
- **Python 3** (versi >= 3.10): `python3 --version`
- **GitHub CLI (`gh`)** *(disarankan)*: `gh --version`
- **Antigravity CLI**: `agy --version`

---

## 2. Langkah Bootstrap Identitas

Setiap workstation memerlukan file identitas lokal `.agent/developer.local.json`. File ini **selalu diabaikan oleh Git** (`gitignored`) sehingga tidak akan pernah ter-commit atau bocor.

### A. Setup Interaktif (Biasa)

Jalankan perintah berikut di root repository:

```bash
python3 scripts/agentic/bootstrap.py
```

Anda akan diminta mengisikan:
1. **Display Name**: Nama lengkap Anda (contoh: `Budi Pratama`).
2. **GitHub Username**: Username GitHub akun aktif Anda (contoh: `budipratama`).
3. **Machine Label**: Label unik workstation ini (contoh: `laptop-thinkpad-dev`).

### B. Setup Non-Interaktif / Scripted

Untuk container, CI, atau konfigurasi otomatis:

```bash
python3 scripts/agentic/bootstrap.py \
  --display-name "Budi Pratama" \
  --github-username "budipratama" \
  --machine-label "workstation-arch" \
  --project-number 1 \
  --project-title "Eva AI Sprint Board" \
  --non-interactive
```

---

## 3. Menjalankan Pemeriksaan Preflight (Doctor)

Setelah bootstrap selesai, jalankan `doctor.py` untuk memastikan seluruh pintu kesiapan terpenuhi:

```bash
python3 scripts/agentic/doctor.py
```

Status yang dilaporkan:
- `✅ [PASS]`: Komponen siap digunakan.
- `⏳ [PENDING_CONFIGURATION]`: Fitur eksternal (misal `gh` atau GitHub Project binding) belum diaktifkan, namun operasional lokal tetap dapat berjalan aman.
- `⚠️  [WARN]`: Peringatan non-fatal (misal kondisi Git detached HEAD).
- `❌ [FAIL]`: Blocker fatal (misal file identitas korup atau tidak ter-gitignore). Operasi tulis akan ditolak hingga diperbaiki.

---

## 4. Penggunaan pada Git Worktree

Jika Anda membuat Git worktree baru pada mesin yang sama:
- Tooling agent secara otomatis menelusuri folder utama (`git rev-parse --git-common-dir`) untuk membaca `.agent/developer.local.json`.
- Anda **tidak perlu mengonfigurasi ulang identitas** untuk setiap worktree lokal di komputer yang sama.
- Pada komputer atau laptop baru, Anda **wajib** menjalankan `bootstrap.py` kembali.

---

## 5. Pemecahan Masalah Mismatch Akun GitHub

Jika GitHub CLI (`gh`) terautentikasi dengan akun yang berbeda dari `.agent/developer.local.json`:
1. Periksa akun aktif:
   ```bash
   gh api user --jq .login
   ```
2. Jika akun `gh` salah, ganti akun melalui:
   ```bash
   gh auth login
   ```
3. Atau perbarui file identitas lokal dengan:
   ```bash
   python3 scripts/agentic/bootstrap.py --force
   ```
