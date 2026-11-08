---
trigger: model_decision
description: Panduan arsitektur modularitas dan kohesi file berdasarkan sweet spot alami (tanpa kuota baris kaku).
---

# Code Cohesion & Natural Modularity Guidelines

Panduan ini mengatur standar modularitas kode pada monorepo Eva AI menggunakan prinsip **Sweet Spot & Natural Separation Boundaries**. Tujuannya adalah menjaga kode tetap bersih, mudah dibaca, dan mudah dipelihara oleh AI Agent serta developer manusia tanpa menimbulkan pemecahan file berlebihan (*over-fragmentation*).

---

## 1. Filosofi Utama: "The Sweet Spot"

- **Hindari Dua Ekstrem**:
  - ❌ **Monolithic "God Files"**: File ribuan baris yang menggabungkan layout tampilan, kalkulasi canvas trigonometri, form modal bertahap, dan logika database.
  - ❌ **Over-Fragmentation**: Memecah kode menjadi puluhan file kerdil (10-30 baris) yang membuat pencarian file dan penelusuran alur kode menjadi sulit.
- **Kunci Pemisahan**: Pisahkan file hanya ketika terdapat **perbedaan tanggung jawab alami (Natural Boundary)** atau **siklus hidup independen (Independent Lifecycle)**.

---

## 2. Kriteria Pemisahan di Flutter Mobile (`apps/eva_mobile`)

### A. Tetap Dipertahankan di File Screen (Jangan Dipecah)
- **Layout Orchestration**: Susunan `Scaffold`, `Column`, `ListView`, dan `AppBar`.
- **Private Helper Builders**: Method lokal privat (seperti `_buildHeader()`, `_buildSummaryCard()`, `_buildStatusChip()`) yang erat kaitannya dengan layout layar dan hanya dipakai di layar tersebut.
- **Screen-level State**: Variabel filter pencarian, tab index, dan data fetching utama via Riverpod.

### B. Wajib Diekstraksi ke File Terpisah (`features/<feature>/presentation/widgets/`)
1. **Komponen dengan Lifecycle / Timer Independen**:
   Sub-widget yang mengelola `Timer` sendiri (misal: *breath pacer*, countdown) atau `TickerProvider` animasi mandiri.
2. **Custom Canvas Rendering (`CustomPainter`)**:
   Komponen yang menggambar langsung ke canvas dengan kalkulasi visual kompleks (misal: audio wave visualizer, orbital nodes, custom charts).
3. **Multi-Step Modal Bottom Sheets & Interactive Dialogs**:
   Modal yang memiliki form input, langkah-langkah panduan (*stepper*), atau interaksi multi-fase.
4. **Reusable UI & Shimmer Loaders**:
   Komponen generik seperti `SkeletonLoader` atau tombol animasi yang memiliki potensi digunakan kembali.

---

## 3. Kriteria Pemisahan di Backend & Services (`apps/backend`)

1. **Pemisahan I/O & Realtime dari Persistensi**:
   Service yang menangani koneksi real-time (WebSockets, STT/TTS streaming) tidak boleh mencampur transaksi SQL langsung di dalam perulangan event. Delegasikan operasi database ke *Persistence Collaborator*.
2. **Peran Router yang Ramping (Thin Controllers)**:
   Router FastAPI (`app/api/routes/`) wajib ramping (3–5 baris per handler), hanya bertugas memvalidasi schema HTTP request, memanggil domain service via `Depends()`, dan mengembalikan Pydantic `response_model`. Dilarang menaruh query SQL mentah kompleks atau kalkulasi bisnis di dalam router handler.
3. **Cohesive Domain Services & Modular Packaging**:
   Bila sebuah domain memiliki beberapa sub-komponen berat (seperti panggilan suara, deteksi emosi, orkestrasi AI), kumpulkan ke dalam direktori paket `app/services/{module}/nama_service.py` dan `app/schemas/{module}/` dengan barrel export `__init__.py`, alih-alih menumpuk file flat di root folder `services/`.
   Lihat panduan lengkap di [.agents/rules/backend-clean-architecture.md](file:///home/mashupsoat/Project/eva-ecosystem/.agents/rules/backend-clean-architecture.md).

---

## 4. Prinsip Component Reuse & Single Source of Truth

Sebelum menulis elemen UI baru atau menduplikasi styling secara *inline* di dalam sebuah screen:
1. **Wajib Memeriksa Komponen Reusable yang Sudah Ada**:
   - Periksa direktori komponen global `apps/eva_mobile/lib/widgets/` (misalnya `AppBackButton`, `GlassCard`, `AppSnackBar`, `CustomButton`, `CustomTextField`, `SkeletonShimmer`, `StaggeredEntrance`).
   - Periksa komponen tingkat fitur di `apps/eva_mobile/lib/features/<feature>/presentation/widgets/`.
2. **Dilarang Menulis Ulang Komponen Standar Secara Inline**:
   - Jangan membuat tombol *back* manual (`IconButton(icon: Icon(Icons.arrow_back...))` atau `Container(...)` bulat) secara terpisah di setiap screen. Selalu gunakan `AppBackButton`.
   - Jangan membuat dialog / card / snack bar secara *ad-hoc* jika sudah tersedia komponen terstandarisasi.
3. **Ekstraksi Jika Dipakai di Lebih Dari 1 Tempat**:
   - Jika sebuah komponen UI memiliki pola visual atau fungsi umum yang dibutuhkan oleh $\ge 2$ layar, ekstraksi menjadi reusable widget di `lib/widgets/` alih-alih menduplikasinya.

---

## 5. Checklist Saat Merancang atau Merefaktor Komponen

- [ ] Apakah sudah memeriksa `apps/eva_mobile/lib/widgets/` untuk memastikan belum ada komponen yang melayani kebutuhan serupa (misal `AppBackButton`, `GlassCard`)? $\rightarrow$ *Wajib gunakan komponen yang sudah ada jika tersedia*
- [ ] Apakah sub-widget ini memiliki `Timer` atau `AnimationController` sendiri yang bisa berjalan independen dari layarnya? $\rightarrow$ *Ekstraksi ke widgets/*
- [ ] Apakah ada class `CustomPainter` yang ditulis di bawah screen? $\rightarrow$ *Ekstraksi ke widgets/*
- [ ] Apakah modal bottom sheet ini cukup panjang dan memiliki alur interaksinya sendiri? $\rightarrow$ *Ekstraksi ke widgets/*
- [ ] Apakah helper privat ini hanya menyusun padding dan widget dasar untuk layar ini? $\rightarrow$ *Pertahankan di file screen*
