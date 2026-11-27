# DESIGN.md — EVA Counselor Mobile

Dial: ENERGY 1 / RHYTHM 2 / MOTION 1

## Visual Language & Identity
**Clinical Calm**: ruang kerja telekonseling psikolog berlisensi yang tenang, tepercaya, dan fokus pada keterbacaan catatan klinis serta ketepatan tindakan selama dan sesudah sesi.

- **Audience**: Psikolog klinis dan konselor mitra/mandiri di Indonesia.
- **Focal Point Policy**: Maksimal 1 focal point utama per layar (Kartu Sesi Mendatang di Beranda, Kartu Saldo Utama di Keuangan, Kontrol Panggilan di Ruang Video Call). Elemen pendukung lainnya tidak bersaing secara visual.
- **Identity Motif**: Kartu putih tenang dengan garis tepi struktural `1px` (`#E2E8F0`) dan aksen periwinkle `#5358CB` yang digunakan hanya pada CTA utama, tab aktif, dan indikator status primer.

## Color Palette (Core + 1 Accent, WCAG AA Verified)
- **Canvas & Surfaces**:
  - Background: `#F8F9FE`
  - Surface / Card: `#FFFFFF`
  - Structural Border: `#E2E8F0`
- **Text Hierarchy (Contrast >= 4.5:1 on `#FFFFFF` and `#F8F9FE`)**:
  - `textPrimary`: `#191C1F` (~16.5:1)
  - `textSecondary`: `#525466` (~6.8:1)
  - `textLight` (muted metadata/caption): `#5F6275` (~5.5:1)
- **Single Deliberate Accent**:
  - `primary`: `#5358CB`
  - `primaryContainer`: `#E8E9FF`
- **Clinical Semantic States**:
  - Verified: text `#1E6B3A` on `#E8F5E9`
  - Pending / Warning: text `#B45309` on `#FFF4E5`
  - High Risk / Error: text `#B91C1C` on `#FFEBEE`

## Typography
- **Font Family**: `Inter` via `google_fonts` — dipilih untuk keterbacaan angka finansial, jadwal jam WIB, dan catatan medis SOAP pada layar ponsel padat informasi.
- **Hierarchy**: Skala jelas antara heading (`26 / 20 / 16`), body (`15 / 13`), dan caption/label (`12`).

## Elevation, Shadows & Glassmorphism Restraint
- **Kartu Reguler & Modal**: Menggunakan `color: AppColors.surface` dan `border: Border.all(color: AppColors.cardBorder)` tanpa `BoxShadow` dan tanpa `BackdropFilter`.
- **Elevasi Selektif**: `BoxShadow` hanya dipakai pada focal point utama (Kartu Hero Sesi / Kartu Saldo Keuangan), tombol CTA primer (`CustomButton`), dan floating bottom navigation bar.
- **Gradasi (`LinearGradient`)**: Dibatasi hanya untuk 1 kartu hero focal point per tab (Kartu Sesi Mendatang / Kartu Saldo Dompet) dan ruang video call.

## Copywriting & Tone
- Bahasa Indonesia profesional, empatik, ringkas, dan jujur tanpa buzzword marketing.
- Dilarang menggunakan karakter em dash (`—`), emoji dekoratif pada judul/toast/tombol/badge/mock tag, panah dekoratif pada CTA, maupun status ALL-CAPS berlebih.
- Status menggunakan Title Case (`Terverifikasi`, `Belum Diverifikasi`, `Tidak Valid`).

## Mobile Responsiveness & Tap Targets
- Seluruh kontrol interaktif memiliki area sentuh minimal `44x44 px` dan umpan balik tap (`InkWell` / ripple).
- Layar di dalam `CounselorMainShellScreen` menyediakan bottom scroll clearance (`MediaQuery.paddingOf(context).bottom + 104`) agar tidak tertutup floating bottom navigation.
- Setiap async view wajib memiliki state `loading` berlabel konteks, `empty` dengan penyebab dan aksi berikutnya, serta `error` yang ramah lengkap dengan tombol `Muat Ulang`.
