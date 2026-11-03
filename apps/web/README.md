# Eva AI - Web Application & Portal

Web front-end untuk ekosistem Eva AI. Repositori ini memuat landing page publik untuk pengenalan aplikasi seluler dan pengunduhan berkas APK beta, serta portal administrasi untuk fasilitas kesehatan mitra dan verifikasi psikolog.

---

## 1. Peran dan Fitur Utama

Aplikasi web ini mencakup dua fungsi utama dalam ekosistem Eva AI:

1. **Landing Page Publik (`/`)**
   - Menampilkan ringkasan fitur konseling suara, misi pemulihan harian, jurnal emosi, dan skrining mandiri (PHQ-9 dan GAD-7).
   - Menyediakan tautan unduh langsung berkas APK Android (`/downloads/eva-beta.apk`) dengan ukuran berkas yang terdeteksi otomatis oleh plugin Vite.
   - Menyertakan widget interaktif, seperti panduan latihan pernapasan (teknik 4-7-8) dan mockup antarmuka aplikasi seluler.

2. **Portal Kemitraan & Administrasi**
   - **Formulir Pengajuan Mitra (`/pengajuan-mitra`)**: Pendaftaran fasilitas kesehatan (rumah sakit, klinik, atau institusi pendidikan) beserta unggahan izin operasional.
   - **Autentikasi Portal (`/login`)**: Halaman masuk untuk staf mitra faskes dan super admin. Dilengkapi pemilih akun cepat saat mode demo aktif.
   - **Admin Dashboard (`/admin`)**: Verifikasi dokumen STR/SIPK tenaga psikolog (mandiri dan faskes), audit berkas, pemantauan rujukan darurat, dan ringkasan metrik tren 60 hari.
   - **Partner Dashboard (`/mitra`)**: Pengelolaan data tenaga psikolog yang bernaung di bawah faskes mitra bersangkutan.

---

## 2. Teknologi yang Digunakan

| Komponen | Pustaka / Alat | Fungsi |
| :--- | :--- | :--- |
| **Framework & Runtime** | React 19 / TypeScript 5 | Fondasi antarmuka berbasis komponen dan tipe data ketat. |
| **Build Tool & Bundler** | Vite 8 | Server pengembangan lokal dan kompilasi build produksi. |
| **Styling** | Tailwind CSS v4 | Utilitas penataan tampilan dengan `@tailwindcss/vite`. |
| **Routing** | React Router v8 (`react-router`) | Manajemen navigasi sisi klien dengan lazy loading komponen halaman. |
| **Ikonografi** | Lucide React | Set ikon antarmuka. |
| **Animasi & Interaksi** | Lenis | Pengguliran halaman halus (*smooth scroll*) pada landing page. |
| **Visualisasi Data** | Recharts | Grafik tren metrik pada admin dashboard. |

---

## 3. Struktur Direktori

```text
apps/web/
├── public/
│   └── downloads/              # Berkas publik unduhan (eva-beta.apk)
├── src/
│   ├── assets/                 # Aset visual statis
│   ├── components/
│   │   ├── mockups/            # Komponen bingkai ponsel dan pratinjau aplikasi seluler
│   │   ├── portal/             # Komponen antarmuka portal (admin, mitra, login, apply)
│   │   ├── sections/           # Bagian halaman landing (Hero, Features, FAQ, CTA, dll.)
│   │   └── ui/                 # Komponen UI dasar (Button, Card, Input, Modal, dll.)
│   ├── config/
│   │   ├── apkMetadata.json    # Metadata ukuran berkas APK (dihasilkan otomatis oleh Vite)
│   │   └── demoConfig.ts       # Konfigurasi saklar mode demo
│   ├── content/
│   │   └── landing.ts          # Salinan teks statis untuk landing page
│   ├── demo/                   # Modul data tiruan dan fitur pengujian non-produksi
│   │   ├── data/               # Data awal psikolog, mitra, dan riwayat metrik
│   │   ├── features/           # Widget pemilih akun cepat dan modal simulasi mobile
│   │   └── README.md           # Panduan pembersihan modul demo untuk produksi
│   ├── hooks/                  # Custom React hooks (useScroll, usePortalDb, dll.)
│   ├── layouts/                # Wrapper tata letak halaman (RootLayout)
│   ├── lib/                    # Utilitas umum (cn.ts, portalStore.ts)
│   ├── pages/                  # Komponen halaman rute
│   ├── services/
│   │   └── portal/             # Lapisan penyimpanan lokal database portal
│   ├── types/                  # Definisi tipe TypeScript untuk portal dan metrik
│   ├── App.tsx                 # Konfigurasi router aplikasi
│   ├── index.css               # Gaya global dan konfigurasi Tailwind CSS
│   └── main.tsx                # Titik masuk aplikasi React
├── package.json                # Daftar dependensi dan script npm
├── tsconfig.json               # Konfigurasi TypeScript
└── vite.config.ts              # Konfigurasi Vite dan plugin metadata APK
```

---

## 4. Panduan Memulai

### Prasyarat
- **Node.js**: Versi 18.0.0 atau lebih baru (direkomendasikan Node.js 20 LTS).
- **npm**: Versi 9 atau lebih baru.

### Instalasi Dependensi
Jalankan perintah berikut dari dalam direktori `apps/web`:
```bash
cd apps/web
npm install
```

### Menjalankan Server Pengembangan
```bash
npm run dev
```
Aplikasi dapat diakses melalui browser pada:
- Local URL: `http://localhost:5174`
- Port terkonfigurasi pada `5174` (ditetapkan dengan `strictPort: true` dan dukungan host lokal).

### Perintah Script Lainnya
- **Build Produksi**: `npm run build` (menjalankan pengecekan tipe `tsc -b` lalu `vite build`).
- **Pratinjau Hasil Build**: `npm run preview` (menjalankan server lokal untuk folder `dist/`).
- **Pengecekan Kode**: `npm run lint` (menjalankan ESLint).

---

## 5. Mode Demo vs Mode Produksi

Aplikasi web menyediakan mode evaluasi lokal agar alur portal admin dan mitra dapat diuji tanpa koneksi backend langsung.

### Konfigurasi Variabel Lingkungan
Mode ini diatur melalui berkas `.env` atau variabel `VITE_ENABLE_DEMO`:

- **Mode Demo Aktif (`VITE_ENABLE_DEMO=true`)**:
  - Memuat data awal tenaga psikolog, faskes mitra, dan riwayat metrik rujukan.
  - Menampilkan menu floating pemilih akun cepat pada halaman `/login`.
  - Mengaktifkan tombol simulasi pendaftaran dari aplikasi seluler pada dashboard admin.

- **Mode Produksi (`VITE_ENABLE_DEMO=false`)**:
  - Menonaktifkan data tiruan dan beralih ke struktur database kosong (`emptyDatabase.ts`).
  - Menyembunyikan seluruh tombol pintas dan widget demo.

Untuk menjalankan build dengan mode demo dinonaktifkan:
```bash
VITE_ENABLE_DEMO=false npm run build
```

Panduan pembersihan modul demo sebelum serah terima produksi (*production handover*) tercantum pada [apps/web/src/demo/README.md](file:///home/oktavian/Project/React/eva-ecosystem/apps/web/src/demo/README.md).

---

## 6. Integrasi Berkas APK Android

Aplikasi web mengelola distribusi berkas installer APK untuk calon pengguna aplikasi seluler Eva:
1. Berkas APK hasil build diletakkan pada lokasi `apps/web/public/downloads/eva-beta.apk`.
2. Saat server Vite dijalankan (`npm run dev` atau `npm run build`), plugin kustom `apkMetadataPlugin` di `vite.config.ts` otomatis membaca ukuran fisik berkas tersebut dan menyimpannya ke `src/config/apkMetadata.json`.
3. Komponen tombol unduh pada landing page membaca nilai ukuran berkas tersebut untuk ditampilkan langsung pada tombol unduh.

