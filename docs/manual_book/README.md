# EVA Ecosystem Manual Book (`#132`)

Direktori sumber LaTeX modular untuk menyusun **1 file PDF Manual Book lengkap** (`EVA_Ecosystem_Manual_Book.pdf`).

## Pembagian File & Isolasi Kontributor

| PIC | File Section yang Dikelola | Folder Screenshot |
|---|---|---|
| `@Oktavian19` | `00_frontmatter.tex`, `01_pendahuluan.tex`, `02_memulai_dan_akun.tex`, `05_web_portal_admin.tex`, `06_alur_lintas_aktor.tex`, `07_privasi_etika_keamanan.tex`, `09_glosarium_penutup.tex` | `figures/web/`, `figures/shared/` |
| `@ekyaaa` | `03_eva_mobile.tex`, bagian Mobile di `08_troubleshooting_faq.tex` | `figures/mobile/` |
| `@KhoirotunNisa25` | `04_eva_counselor.tex`, bagian Counselor di `08_troubleshooting_faq.tex` | `figures/counselor/` |

> **Aturan Isolasi:** Jangan mengubah `main.tex` atau `preamble/styles.tex` pada PR bagian. Gunakan tag **`Part of #132`** pada PR parsial dan **`Closes #132`** pada PR kompilasi PDF final.

## Kompilasi PDF Lokal

Dari root repository:
```bash
make manual-pdf
make manual-clean
```

Output PDF: `docs/manual_book/EVA_Ecosystem_Manual_Book.pdf`.

## Macro yang Tersedia (`preamble/styles.tex`)

- `\uifigure[0.85\textwidth]{mobile/home.png}{Keterangan gambar}{fig:mobile-home}` — otomatis menampilkan placeholder aman bila file gambar belum ditambahkan.
- `\calloutnote{Judul}{Isi}` — kotak catatan informasi (Periwinkle).
- `\callouttip{Judul}{Isi}` — kotak tips praktik terbaik (Hijau).
- `\calloutwarn{Judul}{Isi}` — kotak peringatan/privasi (Amber).
- `\stepbadge{1}` — badge nomor langkah tutorial.

## Aturan Screenshot
- Gunakan data simulasi/dummy. **Dilarang** menampilkan PII asli (email pribadi, nomor STR/SIP asli, nomor rekening, atau catatan klinis pasien nyata).
