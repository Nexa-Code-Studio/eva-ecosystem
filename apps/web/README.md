# EVA Web Application (`apps/web`)

Aplikasi web resmi untuk ekosistem **EVA (Empathetic Vitality Assistant)** yang mencakup Landing Page publik, Portal Mitra Fasilitas Kesehatan (Faskes), serta Panel Administrasi Ekosistem EVA.

---

## 1. Struktur Arsitektur (Clean Architecture Separation)

Kode sumber di dalam `src/` dirancang dengan pemisahan tanggung jawab (separation of concerns) yang tegas antara **UI Layer**, **Schema & API Contracts**, **Service Abstraction Layer**, dan **Mock Data Layer**:

```text
src/
├── config/
│   └── appConfig.ts                 # Single-point configuration (VITE_USE_MOCK_DATA & VITE_API_BASE_URL)
├── types/
│   ├── domain/                      # Model entitas domain murni
│   │   ├── portal.ts                # Entitas Mitra Faskes, Psikolog/Relawan, Rujukan, User, Quest, CrisisConfig
│   │   └── dashboard.ts             # Model metrik dan analitik dashboard admin
│   ├── api/
│   │   └── contracts.ts             # Skema kontrak API & DTO (Request / Response payloads)
│   ├── portal.ts                    # Barrel ekspor tipe portal & kontrak API
│   └── adminDashboard.ts            # Barrel ekspor tipe analitik dashboard
├── data/
│   └── mock/                        # Mock Data Layer (terisolasi penuh dari komponen UI)
│       ├── auth.mock.ts             # Kredensial mock admin untuk pengujian lokal
│       ├── partners.mock.ts         # Data awal (seed) Mitra Faskes
│       ├── psychologists.mock.ts    # Data awal Psikolog & Relawan beserta generator simulasi
│       ├── ecosystem.mock.ts        # Data awal Rujukan, Pengguna Umum, Coping Quests, Waitlist, FAQ
│       ├── dashboardMetrics.mock.ts # Data historis 60 hari & baseline distribusi DASS-21
│       ├── certificateSvgTemplates.ts # Template dokumen sertifikat SVG untuk mode mock
│       ├── landing.mock.ts          # Konten statis landing page
│       └── index.ts                 # Barrel penyedia snapshot database mock
├── services/
│   ├── contracts/
│   │   └── portalDataSource.ts      # Interface kontrak abstraksi IPortalDataSource
│   ├── mock/
│   │   └── mockPortalDataSource.ts  # Implementasi data source berbasis localStorage + mock seed
│   ├── remote/
│   │   └── remotePortalDataSource.ts # Implementasi data source untuk koneksi API produksi (FastAPI)
│   └── portal/
│       ├── storage.ts               # Provider switching (Mock vs Remote) & state snapshot
│       ├── partnerService.ts        # Use-case & layanan manajemen Mitra Faskes
│       ├── psychologistService.ts   # Use-case & layanan manajemen Psikolog/Relawan
│       ├── ecosystemService.ts      # Use-case rujukan, misi koping, konfigurasi krisis, waitlist, FAQ
│       └── emptyDatabase.ts         # State awal kosong untuk mode produksi
├── lib/
│   ├── portalStore.ts               # Facade tunggal yang dikonsumsi oleh layer UI dan Hooks
│   └── cn.ts                        # Utilitas penggabungan class Tailwind CSS
├── hooks/                           # Custom React hooks (murni mengonsumsi portalStore facade)
├── components/
│   ├── ui/                          # Komponen UI primitif reusable (Button, Card, Modal, dll.)
│   ├── layout/                      # Komponen navigasi utama & footer
│   ├── sections/                    # Seksi halaman Landing Page
│   ├── mockups/                     # Ilustrasi layar interaktif aplikasi mobile EVA
│   ├── modals/                      # Modal informasi dan evaluasi klinis
│   ├── portal/                      # Modul UI Portal Admin dan Portal Mitra Faskes
│   └── devtools/                    # Adapter widget bantu pengujian (otomatis nonaktif di mode produksi)
└── pages/                           # Komponen halaman tingkat rute (Route Pages)
```

### Prinsip Isolasi Layer
1. **UI Layer Agnostik terhadap Sumber Data**: Komponen di `src/pages/`, `src/components/`, dan `src/hooks/` tidak mengimpor file dari `src/data/mock/` secara langsung. Seluruh akses data melalui abstraksi di `src/lib/portalStore.ts` dan `src/services/`.
2. **Single-Point Switching**: Peralihan antara mode Mock Data dan mode Production API dikendalikan sepenuhnya melalui `src/config/appConfig.ts`.

---

## 2. Prasyarat & Cara Menjalankan Secara Lokal

### Prasyarat
- **Node.js**: versi `20.x` atau lebih baru
- **npm**: versi `10.x` atau lebih baru

### Instalasi Dependensi
Jalankan perintah berikut dari direktori `apps/web`:

```bash
npm install
```

### Menjalankan Server Development (Default: Mode Mock Data Aktif)
Secara default, aplikasi langsung berjalan menggunakan data dari `src/data/mock/` sehingga seluruh alur fitur dapat diuji tanpa memerlukan koneksi ke backend:

```bash
npm run dev
```

Aplikasi dapat diakses melalui browser pada alamat yang ditampilkan di terminal (umumnya `http://localhost:5173`).

### Pemeriksaan Kode (Linter) & Build Produksi

```bash
# Menjalankan ESLint
npm run lint

# Melakukan kompilasi TypeScript dan memaketkan build produksi ke folder dist/
npm run build

# Menjalankan pratinjau hasil build produksi
npm run preview
```

---

## 3. Konfigurasi Environment (Mock vs Production API)

Pengaturan sumber data dikontrol menggunakan variabel environment Vite (dapat diatur melalui file `.env.local` di dalam `apps/web`):

| Variabel Environment | Default | Deskripsi |
| :--- | :--- | :--- |
| `VITE_USE_MOCK_DATA` | `true` | Jika `true`, aplikasi menggunakan `MockPortalDataSource` (`src/data/mock/`). Jika `false`, aplikasi beralih ke `RemotePortalDataSource` tanpa data dummy. |
| `VITE_API_BASE_URL` | `http://localhost:8888/api/v1` | URL endpoint FastAPI backend saat berjalan pada mode produksi/live API. |
| `VITE_ENABLE_DEMO_TOOLS` | `true` (saat mock aktif) | Mengontrol visibilitas widget bantu pengujian (`QuickLoginDevTool`, `MobilePsychologistSimulator`, dan `ResetPortalDataAction`). Otomatis bernilai `false` saat `VITE_USE_MOCK_DATA=false`. |

### Contoh Menjalankan Mode Produksi (Tanpa Mock Data & Tanpa DevTools)

```bash
VITE_USE_MOCK_DATA=false npm run dev
```

Atau untuk proses build produksi murni:

```bash
VITE_USE_MOCK_DATA=false VITE_API_BASE_URL=https://api.eva.id/api/v1 npm run build
```
