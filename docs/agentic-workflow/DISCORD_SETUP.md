# Panduan Konfigurasi Notifikasi Discord

Dokumen ini menjelaskan langkah-langkah pengaturan incoming webhook Discord dan konfigurasi GitHub Secrets & Variables untuk notifikasi otomatis.

---

## 1. Keamanan Utama: Tidak Ada Kredensial di Kode Sumber

- **Dilarang Keras** meletakkan URL Webhook Discord di file repositori, issue, commit, atau logs.
- URL Webhook dan pemetaan User ID Discord **hanya disimpan pada GitHub Secrets**.
- Kanal Discord yang digunakan **harus merupakan kanal privat internal tim**, bukan kanal publik.

---

## 2. Membuat Incoming Webhook di Discord

1. Buka server Discord tim.
2. Masuk ke **Server Settings** ➔ **Integrations** ➔ **Webhooks**.
3. Klik **New Webhook**, beri nama (misal: `Eva AI Dev Bot`), dan pilih kanal privat tujuan.
4. Klik **Copy Webhook URL**.

---

## 3. Konfigurasi GitHub Secrets (Wajib)

Masuk ke repository GitHub: **Settings** ➔ **Secrets and variables** ➔ **Actions** ➔ **New repository secret**:

### A. Secret 1: `DISCORD_WEBHOOK_URL`
- **Name**: `DISCORD_WEBHOOK_URL`
- **Value**: Masukkan Webhook URL lengkap yang di-copy dari Discord (contoh format: `https://discord.com/api/webhooks/123456789/abcdef...`).

### B. Secret 2: `DISCORD_MENTION_MAP`
Pemetaan antara **GitHub username** (huruf kecil) dan **Discord Numeric User ID** agar bot dapat mem-ping developer yang bersangkutan secara akurat:
- **Name**: `DISCORD_MENTION_MAP`
- **Value**: String JSON format valid:
  ```json
  {
    "budipratama": "284729104857201948",
    "sitirizka": "194820485928104857"
  }
  ```
  *(Cara mendapatkan Discord User ID: aktifkan Developer Mode di Discord ➔ klik kanan nama user ➔ Copy User ID).*

---

## 4. Konfigurasi GitHub Variables (Non-Secret)

Masuk ke **Settings** ➔ **Secrets and variables** ➔ **Actions** ➔ Tab **Variables**:

| Variable Name | Default Value | Keterangan |
| :--- | :--- | :--- |
| `DISCORD_NOTIFICATIONS_ENABLED` | `true` | Saklar utama pengaktifan notifikasi |
| `DISCORD_NOTIFY_ISSUES` | `true` | Notifikasi saat issue baru dibuat |
| `DISCORD_NOTIFY_ASSIGNMENT` | `true` | Notifikasi saat issue ditugaskan ke developer |
| `DISCORD_NOTIFY_PR` | `true` | Notifikasi saat PR siap direview |
| `DISCORD_NOTIFY_CI_FAILURE` | `true` | Notifikasi saat CI gagal pada branch aktif |

---

## 5. Uji Coba Pengiriman Notifikasi (Dry-Run & Live)

### Uji Coba Lokal Dry-Run (Aman, Tanpa Mengirim Pesan)
```bash
python3 scripts/agentic/notify-discord.py \
  --event issue_assigned \
  --title "Implementasi Fitur Mood Tracker" \
  --url "https://github.com/Nexa-Code-Studio/eva-ecosystem/issues/128" \
  --actor "budipratama" \
  --details "Ditugaskan untuk sprint minggu ini" \
  --dry-run
```

Output akan menampilkan struktur payload JSON, embed warna, dan target mention tanpa melakukan request ke internet.

---

## 6. Penanganan Masalah (Troubleshooting)

- **HTTP 401 / 404**: Webhook URL tidak valid atau telah dihapus di Discord. Perbarui nilai `DISCORD_WEBHOOK_URL` di GitHub Secrets.
- **HTTP 429**: Rate limit Discord terlampaui. Script `notify-discord.py` secara otomatis melakukan backoff dan retry sesuai header `retry_after`.
- **Tidak ada mention**: Pastikan username GitHub di `DISCORD_MENTION_MAP` ditulis dengan huruf kecil (*lowercase*) dan User ID berupa angka murni tanpa tanda kurung atau `<@...>`.
