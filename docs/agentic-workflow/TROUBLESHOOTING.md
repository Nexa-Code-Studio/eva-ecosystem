# Panduan Pemecahan Masalah (Troubleshooting)

Kumpulan solusi untuk kendala umum yang mungkin dihadapi saat menjalankan workflow agentic.

---

## 1. Masalah Identitas & Doctor Preflight

### Kendala: `doctor.py` gagal dengan pesan `Missing developer identity file`
- **Penyebab**: File `.agent/developer.local.json` belum dibuat pada workstation ini.
- **Solusi**: Jalankan `python3 scripts/agentic/bootstrap.py` untuk menginisialisasi identitas lokal Anda.

### Kendala: `identity_gitignored` melaporkan `[FAIL]`
- **Penyebab**: File `.agent/developer.local.json` belum tercantum di `.gitignore`.
- **Solusi**: Buka `.gitignore` dan tambahkan baris:
  ```gitignore
  .agent/developer.local.json
  .agent/*.local.json
  .agent/worktrees/
  ```

### Kendala: `Authenticated GitHub user does not match developer.local.json`
- **Penyebab**: Akun aktif pada GitHub CLI (`gh api user`) berbeda dengan `github_username` yang didaftarkan di config lokal.
- **Solusi**: 
  - Jika akun di `gh` yang benar: jalankan `python3 scripts/agentic/bootstrap.py --force` untuk memperbarui config lokal.
  - Jika config lokal yang benar: ganti akun di GitHub CLI dengan `gh auth login`.

---

## 2. Masalah Cabang & Worktree

### Kendala: `Branch does not match convention {type}/{issue}-{slug}`
- **Penyebab**: Branch yang digunakan tidak mengikuti format standar.
- **Solusi**: Buat branch baru menggunakan `start-task.py`:
  ```bash
  python3 scripts/agentic/start-task.py --type feat --issue 128 --slug mood-tracker
  ```

### Kendala: `Worktree directory already exists`
- **Penyebab**: Direktori worktree pada `.agent/worktrees/<name>` belum dihapus dari sesi sebelumnya.
- **Solusi**: 
  - Jika worktree sudah selesai: jalankan `git worktree remove .agent/worktrees/<name>`.
  - Jika masih ingin digunakan: navigasikan langsung ke direktori tersebut (`cd .agent/worktrees/<name>`).

---

## 3. Masalah Transisi Status (`sync-state`)

### Kendala: `Transition to 'In Review' requires a valid Pull Request URL`
- **Penyebab**: Mencoba memindahkan status ke `In Review` tanpa memberikan parameter `--pr-url` yang valid.
- **Solusi**: Buka PR terlebih dahulu di GitHub, lalu sertakan URL PR dan bukti pengujian:
  ```bash
  python3 scripts/agentic/sync-state.py \
    --state "In Review" \
    --pr-url "https://github.com/Nexa-Code-Studio/eva-ecosystem/pull/42" \
    --test-evidence "python3 -m unittest passed"
  ```

### Kendala: `Transition to 'Done' requires PR to be merged`
- **Penyebab**: Mencoba menandai tugas selesai sebelum PR di-merge ke branch utama.
- **Solusi**: Pastikan PR telah di-merge, lalu jalankan dengan flag `--pr-merged`.

---

## 4. Masalah CI & Notifikasi Discord

### Kendala: Workflow `agentic-notifications` di GitHub Actions dilewati (skip)
- **Penyebab**: Variable `DISCORD_NOTIFICATIONS_ENABLED` bernilai `false` atau Secret `DISCORD_WEBHOOK_URL` belum diisi di repository settings.
- **Solusi**: Ikuti panduan di [DISCORD_SETUP.md](./DISCORD_SETUP.md) untuk mengatur Secret dan Variable di GitHub Repository Settings.

### Kendala: Discord mengembalikan error HTTP 429
- **Penyebab**: Terlalu banyak event terpicu dalam waktu singkat (*rate limiting*).
- **Solusi**: `notify-discord.py` sudah menangani retry otomatis secara backoff. Jika masih berlanjut, nonaktifkan event notifikasi yang kurang penting (misal `DISCORD_NOTIFY_ISSUES=false`).
