# 📱 EVA Mobile Mockup Screenshot Pipeline

Pipeline otomatisasi tangkapan layar fitur **EVA Mobile** untuk ditampilkan secara presisi pada mockup ponsel di Landing Page Web (`Hero` dan `Features`).

---

## 🚀 Cara Menjalankan

Dari direktori `apps/web`:

```bash
# 1. Jalankan update tangkapan layar (menggunakan build Flutter web yang ada)
npm run update:mockups

# 2. Atau kompilasi ulang Flutter web dari source terbaru lalu ambil screenshot:
npm run update:mockups -- --rebuild
```

Atau langsung dari root monorepo:

```bash
npm --prefix apps/web run update:mockups
```

---

## 📂 Struktur Output (`apps/web/public/images/mockups/`)

File tangkapan layar disimpan dalam format **WebP** teroptimasi (~40-60 KB) dan **PNG** (retina 2x 780x1688):

| File | Fitur | Route di eva_mobile | Penempatan di Web |
| :--- | :--- | :--- | :--- |
| `home.webp` | Beranda Eva Mobile | `/#/home` | Mockup Ponsel di **Hero Section** |
| `voice.webp` | Curhat Suara Interaktif | `/#/voice_call` | Carousel Tab **Curhat Suara** |
| `diary.webp` | Diari Emosi AI | `/#/diary` | Carousel Tab **Diari AI** |
| `screening.webp` | Skrining DASS-21 | `/#/dass` | Carousel Tab **Skrining DASS-21** |
| `safety.webp` | Protokol SafetyNet | `/#/support` | Carousel Tab **SafetyNet 24/7** |
| `quest.webp` | Misi Ketahanan Emosi | `/#/monitoring` | Carousel Tab **Misi Ketahanan** |
| `avatar.webp` | Personalisasi Sahabat | `/#/settings` | Carousel Tab **Sahabat AI** |

---

## 🛡️ Mekanisme Fallback

Komponen [`PhoneFrame.tsx`](file:///home/oktavian/Project/React/eva-ecosystem/apps/web/src/components/mockups/PhoneFrame.tsx) dan [`AppScreens.tsx`](file:///home/oktavian/Project/React/eva-ecosystem/apps/web/src/components/mockups/AppScreens.tsx) dilengkapi dengan pendeteksi `onError`:
- Jika file gambar `.webp` tersedia, screenshot asli akan dirender secara tajam.
- Jika file gambar belum di-generate atau gagal dimuat, sistem otomatis memunculkan komponen mockup React bawaan tanpa merusak layout.

