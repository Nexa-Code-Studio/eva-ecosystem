# Developer Onboarding Runbook: Eva AI Agentic Workflow

> **Dokumen:** Panduan Persiapan Lingkungan Pengembang dan Penautan Identitas.  
> **Sasaran:** Memastikan pengembang baru atau mesin baru siap bekerja dalam alur kerja kolaboratif terintegrasi.

---

## 1. Dua Tingkat Kesiapan Lingkungan

Untuk menjamin alur kerja tetap berfungsi saat offline atau saat GitHub CLI belum dikonfigurasi, sistem membedakan dua tingkat kesiapan:

```text
┌──────────────────────────────────────────────┐
│  1. LOCAL_READY                              │
│  - File identitas (.agent/developer.local.json)│
│  - Git repo & working tree sehat             │
│  - Rules & skills aktif di .agents/          │
│  - Hook preflight siap                       │
│  -> Dapat langsung coding, branch, dan test! │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│  2. REMOTE_READY                             │
│  - GitHub CLI ('gh') terpasang               │
│  - 'gh auth status' terautentikasi           │
│  - Username GitHub sinkron dengan identitas  │
│  - Binding GitHub Project v2 aktif           │
│  -> Dapat sinkronisasi status & PR otomatis! │
└──────────────────────────────────────────────┘
```

Jika mesin berstatus `LOCAL_READY` namun `REMOTE_READY` masih `PENDING_CONFIGURATION`:
Pengembang tetap dapat membuat branch, mengedit kode, dan menjalankan test secara normal. Sinkronisasi status remote dapat diselesaikan kemudian.

---

## 2. Langkah Demi Langkah Onboarding

### Langkah 1: Jalankan Preflight Diagnostic
Periksa kesiapan awal mesin Anda:

```bash
python3 scripts/agentic/doctor.py
```

Jika muncul pesan `❌ [FAIL] identity_file`, lanjutkan ke Langkah 2.

---

### Langkah 2: Buat Identitas Lokal Mesin (Bootstrap)

Jalankan script inisialisasi identitas:

```bash
python3 scripts/agentic/bootstrap.py
```

Script akan menanyakan data non-sensitif:
1. **Nama Lengkap (Display Name)**: Nama panggilan Anda (contoh: `Alexander Agung Raya`).
2. **GitHub Username**: Username GitHub Anda (contoh: `ekyaaa`).
3. **Machine Label**: Label unik mesin/laptop Anda (contoh: `dev-laptop-nobara`).

Secara non-interaktif:
```bash
python3 scripts/agentic/bootstrap.py \
  --display-name "Alexander Agung" \
  --github-username "ekyaaa" \
  --machine-label "dev-nobara"
```

> [!IMPORTANT]
> File `.agent/developer.local.json` **selalu diabaikan oleh Git (.gitignore)**. File ini tidak memuat token rahasia, password, atau webhook URL.

---

### Langkah 3: Konfigurasi GitHub CLI (Untuk Kesiapan Remote)

Jika `gh` belum terpasang di sistem Anda:

- **Nobara / Fedora / RHEL**:
  ```bash
  sudo dnf install gh
  ```
- **Ubuntu / Debian**:
  ```bash
  sudo apt install gh
  ```
- **Arch Linux**:
  ```bash
  sudo pacman -S github-cli
  ```
- **macOS**:
  ```bash
  brew install gh
  ```

Setelah terpasang, lakukan autentikasi:
```bash
gh auth login
```
Pilih opsi **SSH** atau **HTTPS**, lalu ikuti verifikasi web di browser.

---

### Langkah 4: Tautkan Akun Discord dengan GitHub (Hanya Sekali per Akun)

Integrasi notifikasi dan penugasan menggunakan sistem OAuth 2.0 PKCE yang dikelola langsung oleh bot Discord:

1. Buka server Discord tim pengembang.
2. Pada kanal teks mana saja, jalankan slash command:
   ```text
   /account connect
   ```
3. Bot akan mengirim pesan rahasia (*ephemeral*) berisi tautan otorisasi GitHub.
4. Klik tautan tersebut dan izinkan otorisasi di browser Anda.
5. Jalankan perintah verifikasi:
   ```text
   /account status
   ```
6. Bot akan menampilkan status terverifikasi beserta peran Anda (`Developer` / `Maintainer`).

> [!NOTE]
> Penautan akun ini disimpan pada database SQLite bot di server, bukan di repositori Git lokal. Anda tidak perlu mengulang penautan ini saat berganti laptop/perangkat.

---

## 3. Bekerja dengan Git Worktrees

Jika Anda bekerja secara paralel dengan Git Worktree:
- Script utilitas (`doctor.py`, `tasks.py`, `start-task.py`) secara otomatis mendeteksi konfigurasi identitas dari direktori kerja utama (`main worktree`).
- Jika diperlukan konfigurasi per-worktree, atur variabel lingkungan `AGENTIC_DEV_CONFIG=/path/to/custom.json`.
