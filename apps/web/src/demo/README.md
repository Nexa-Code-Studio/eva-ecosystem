# Modul Data & Fitur Demo (Non-Production)

Folder ini mengonsolidasikan seluruh **data dummy (mock)** dan **fitur khusus demo/evaluasi** yang tidak diperuntukkan bagi lingkungan *production*.

---

## 1. Struktur Folder

```
src/demo/
├── data/
│   ├── certificateSvgTemplates.ts  # Generator gambar sertifikat SVG mandiri & faskes
│   ├── initialPartners.ts          # Data dummy kemitraan faskes
│   ├── initialPsychologists.ts     # Data dummy psikolog (mandiri & faskes) + salinan berkas
│   ├── initialEcosystem.ts         # Data rujukan, pengguna umum, misi koping, waitlist, FAQ
│   ├── dashboardHistorySeed.ts     # Seed metrik tren 60 hari admin dashboard
│   └── demoDatabase.ts             # Agregasi PortalDatabase untuk mode demo
├── features/
│   ├── DemoAccountsMenu.tsx        # Widget floating pemilih akun cepat di /login
│   ├── SimulateMobilePsyModal.tsx  # Modal simulasi pendaftaran psikolog dari aplikasi mobile
│   └── simulateSubmission.ts       # Logika simulasi pendaftaran psikolog mobile
└── README.md                       # Dokumentasi ini
```

---

## 2. Cara Mengaktifkan / Menonaktifkan Mode Demo

Seluruh fitur demo dan data dummy dikendalikan melalui konfigurasi di [`src/config/demoConfig.ts`](../config/demoConfig.ts) dan variabel *environment*:

```bash
# Untuk Menonaktifkan Demo (Mode Kosong / Produksi):
VITE_ENABLE_DEMO=false npm run build
```

Atau setel dalam file `.env` / `.env.production`:
```env
VITE_ENABLE_DEMO=false
```

Ketika `VITE_ENABLE_DEMO=false`:
1. Database portal otomatis menggunakan [`EMPTY_PORTAL_DATABASE`](../services/portal/emptyDatabase.ts).
2. Widget akun cepat di halaman login disembunyikan.
3. Tombol "Simulasikan Pendaftaran Mobile" di menu Psikolog Mandiri disembunyikan.
4. Tombol "Reset Demo" di Topbar Admin disembunyikan.
5. Metrik tren dashboard kembali ke angka riil 0 tanpa seed tiruan.

---

## 3. Cara Menghapus Folder Ini Secara Permanen (Production Handover)

Jika Anda ingin membersihkan seluruh data dan kode demo sebelum diserahkan ke tim backend atau deployment:

1. **Hapus folder demo**:
   ```bash
   rm -rf src/demo
   ```

2. **Perbarui konfigurasi di `src/config/demoConfig.ts`**:
   Setel semua flag ke `false`.

3. **Perbarui impor di `src/services/portal/storage.ts`**:
   Gunakan langsung `EMPTY_PORTAL_DATABASE` sebagai basis database default:
   ```ts
   import { EMPTY_PORTAL_DATABASE } from './emptyDatabase'
   export const INITIAL_DB = EMPTY_PORTAL_DATABASE
   ```

4. **Selesai**: Seluruh modul inti produksi tetap bersih, modular, dan bebas dari dependensi berkas demo.

