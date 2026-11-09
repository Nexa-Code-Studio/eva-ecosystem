# 🎬 EVA Web Automated Demo & Video Slicer

Modul script otomatisasi demo fitur Web EVA berbasis **Playwright Headed (1080p)**, sinkronisasi **Spectacle**, dan pemotong video modular menggunakan **FFmpeg**.

---

## 📌 Cara Menjalankan

> [!IMPORTANT]
> Script ini berada di workspace **`apps/web`**. Pastikan Anda berpindah ke folder `apps/web` terlebih dahulu sebelum menjalankan perintah NPM, atau gunakan flag `--prefix apps/web`.

### 1. Jalankan Perekaman Otomatis Penuh (Durasi Penuh ~5 Menit 20 Detik)
Membuka browser otomatis di layar laptop Anda (`1920x1080`), menampilkan hitung mundur 5 detik untuk Spectacle, menjalankan 12 segmen fitur dengan tempo natural, lalu otomatis memotong video menjadi 12 file `.mp4`. File lama di `recordings/clips/` akan **ditimpa (*overwrite*)**.

```bash
# Dari root monorepo:
cd apps/web && npm run demo:record

# Atau langsung dari root tanpa cd:
npm --prefix apps/web run demo:record
```

### 2. Jalankan Perekaman Tempo Cepat (Fast Preview Mode ~2.5 Menit)
Cocok untuk verifikasi cepat alur E2E:

```bash
cd apps/web && npm run demo:record:fast
```

### 3. Memotong Video Rekaman Layar Eksternal (Spectacle)
Jika Anda merekam seluruh layar laptop menggunakan KDE Spectacle saat script Playwright berjalan, Anda bisa memotong video Spectacle tersebut menjadi 12 bagian rapi sesuai penanda waktu (*timestamps*):

```bash
cd apps/web
npm run demo:slice -- /path/ke/video-spectacle.mp4 --out=clips-spectacle
```

---

## 📂 Struktur Output Video (`apps/web/recordings/`)

```
apps/web/recordings/
├── 00-full-eva-web-demo.mp4       # Video utuh rekaman demo Playwright (1080p H.264)
├── timestamps.json                # Metadata penanda detik mulai dan selesai aktual
├── raw/                           # Video capture mentah dari Playwright (.webm)
└── clips/                         # 12 File video hasil potongan per segmen:
    ├── 01-publik-landing-page.mp4
    ├── 02-pengajuan-mitra-faskes.mp4
    ├── 03-login-dan-cek-status-mitra.mp4
    ├── 04-admin-dashboard-overview.mp4
    ├── 05-admin-verifikasi-mitra-faskes.mp4
    ├── 06-admin-verifikasi-dan-simulasi-psikolog.mp4
    ├── 07-admin-triage-rujukan-klinis.mp4
    ├── 08-admin-pengguna-dan-transaksi-koin.mp4
    ├── 09-admin-cms-konten-dan-katalog-koin.mp4
    ├── 10-mitra-triage-rujukan-pasien.mp4
    ├── 11-mitra-manajemen-psikolog.mp4
    └── 12-mitra-profil-faskes.mp4
```

---

## 📋 Daftar 12 Segmen Fitur

| No | File Output | Route | Deskripsi Utama |
| :-: | :--- | :--- | :--- |
| **01** | `01-publik-landing-page.mp4` | `/` | Hero, Breathing Widget, Mockup Fitur, Cara Kerja, USP, FAQ & CTA |
| **02** | `02-pengajuan-mitra-faskes.mp4` | `/pengajuan-mitra` | Form Wizard 3 Tahap (Faskes, PIC, Akun Login Instansi) |
| **03** | `03-login-dan-cek-status-mitra.mp4` | `/login` | Pengecekan status mitra (Pending, Revisi) & Login Admin |
| **04** | `04-admin-dashboard-overview.mp4` | `/admin/dashboard` | KPI Eksekutif, Tren Konseling & Distribusi DASS-21 |
| **05** | `05-admin-verifikasi-mitra-faskes.mp4` | `/admin/partners` | Tinjau dokumen izin faskes & persetujuan mitra baru |
| **06** | `06-admin-verifikasi-dan-simulasi-psikolog.mp4` | `/admin/psychologists` | Simulasi pendaftaran mobile & verifikasi STR/SIPP psikolog |
| **07** | `07-admin-triage-rujukan-klinis.mp4` | `/admin/referrals` | Triage pasien DASS-21 & penugasan psikolog pendamping |
| **08** | `08-admin-pengguna-dan-transaksi-koin.mp4` | `/admin/users-coins` | Direktori pengguna aplikasi & riwayat transaksi koin suara |
| **09** | `09-admin-cms-konten-dan-katalog-koin.mp4` | `/admin/content-config` | CMS Misi Koping, Hotline Krisis, Paket Koin, FAQ & Logout |
| **10** | `10-mitra-triage-rujukan-pasien.mp4` | `/mitra/referrals` | Portal Mitra: Toggle rujukan, antrean pasien & assign dokter/psikolog |
| **11** | `11-mitra-manajemen-psikolog.mp4` | `/mitra/psychologists` | Portal Mitra: Tambah psikolog naungan faskes & setting tarif koin |
| **12** | `12-mitra-profil-faskes.mp4` | `/mitra/profile` | Portal Mitra: Legalitas, jam operasional, kapasitas & Logout |

