# Discord Bot Administrator & VPS Operations Checklist

> **Dokumen:** Panduan Verifikasi dan Checklist Administrator Bot Discord.  
> **Sasaran:** Memastikan integrasi antara repositori GitHub `eva-ecosystem`, GitHub App, dan Discord Bot berjalan aman tanpa kebocoran kredensial.

---

## 1. Verifikasi Variabel Lingkungan di Server VPS (`.env`)

Pastikan seluruh variabel wajib telah terisi pada runtime bot di VPS (tanpa mencetak nilai rahasia di log publik):

| Variabel Lingkungan | Nilai yang Diharapkan | Keterangan |
| :--- | :--- | :--- |
| `NODE_ENV` | `production` | Mode runtime produksi Fastify & Discord.js |
| `PORT` | `8080` (atau port reverse proxy) | Port HTTP server Fastify webhook receiver |
| `PUBLIC_BASE_URL` | `https://bot.domain-anda.com` | URL publik HTTPS untuk webhook dan OAuth callback |
| `GITHUB_OWNER` | `Nexa-Code-Studio` | Akun/Organisasi pemilik repositori target |
| `GITHUB_REPOSITORY` | `eva-ecosystem` | Nama repositori target integrasi |
| `GITHUB_PROJECT_NUMBER` | `<Nomor Project v2>` | Nomor Project v2 kanonikal tim |
| `GITHUB_APP_ID` | `<Angka ID>` | App ID dari halaman pengaturan GitHub App |
| `GITHUB_APP_CLIENT_ID` | `<String Client ID>` | Client ID OAuth GitHub App |
| `GITHUB_APP_CLIENT_SECRET` | *(Secret tersimpan aman)* | Client Secret OAuth GitHub App |
| `GITHUB_APP_INSTALLATION_ID`| `<Angka ID>` | ID instalasi GitHub App pada repositori target |
| `GITHUB_APP_PRIVATE_KEY_PATH`| `secrets/github-app.pem` | Path ke file private key RSA PEM (izin: `chmod 600`) |
| `GITHUB_WEBHOOK_SECRET` | *(Secret minimal 32 karakter)*| Secret verifikasi HMAC SHA-256 webhook |
| `DISCORD_APPLICATION_ID` | `<Discord App ID>` | Application ID bot pada Discord Developer Portal |
| `DISCORD_GUILD_ID` | `<Discord Server ID>` | ID Server Discord tim pengembang |
| `DISCORD_NOTIFICATION_CHANNEL_ID` | `<Discord Channel ID>` | ID kanal privat tempat embed notifikasi dikirim |
| `DISCORD_BOT_TOKEN` | *(Secret token bot)* | Token bot Discord |
| `TOKEN_ENCRYPTION_KEY` | *(32-byte hex string / 64 char)* | Kunci AES-256-GCM enkripsi token OAuth di SQLite |
| `BOT_WRITE_ACTIONS_ENABLED`| `true` | Mengaktifkan slash command write (`/issue status`, dll.) |

---

## 2. Checklist Konfigurasi GitHub App

Buka pengaturan GitHub App di GitHub:

- [ ] **Webhook Active**: Tercentang aktif.
- [ ] **Webhook URL**: Mengarah ke `https://<PUBLIC_BASE_URL>/webhooks/github` (Wajib HTTPS dengan sertifikat valid).
- [ ] **SSL Verification**: Aktif (*Enable SSL verification*).
- [ ] **Permissions**:
  - `Issues`: Read and write.
  - `Pull requests`: Read-only.
  - `Metadata`: Read-only.
  - `Projects`: Read and write (di tingkat organisasi).
- [ ] **Event Subscriptions**:
  - `Issues`
  - `Issue comment`
  - `Pull request`
  - `Workflow run`
  - `Check suite`
  - `Projects v2 item`
- [ ] **App Installation**: GitHub App terpasang pada `Nexa-Code-Studio/eva-ecosystem` dengan akses repositori terverifikasi.

---

## 3. Verifikasi Status Kesehatan Layanan (Health Check)

Setelah bot dijalankan melalui Docker Compose di VPS:

```bash
# Periksa health status lokal di server
curl -f http://127.0.0.1:8080/health
```

Output yang diharapkan:
```json
{
  "status": "ok",
  "database": "connected",
  "discord": "ready"
}
```

---

## 4. Prosedur Uji Coba Penautan Akun Tim (OAuth 2.0 PKCE)

1. Minta satu pengembang menjalankan:
   ```text
   /account connect
   ```
2. Pengembang menyetujui otorisasi di browser.
3. Jalankan perintah verifikasi:
   ```text
   /account status
   ```
4. Pastikan response menampilkan username GitHub dan peran hak akses yang sesuai.

---

## 5. Prosedur Uji Coba Webhook Delivery

1. Masuk ke halaman GitHub App ➔ **Advanced** ➔ **Recent Deliveries**.
2. Pilih delivery terbaru (misal: event `issues` atau ping).
3. Klik **Redeliver**.
4. Periksa log bot di VPS:
   ```bash
   docker compose logs --tail 20 -f bot
   ```
5. Pastikan log mencatat verifikasi tanda tangan sukses (`202 Accepted` atau `200 Duplicate acknowledged`) dan worker berhasil mengirim pesan ke Discord.
