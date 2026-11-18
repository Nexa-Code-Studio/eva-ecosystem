#!/usr/bin/env python3
"""
Creates all 6 verified task issues for Eva Ecosystem.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gh_project import create_issue

ISSUES = [
    {
        "title": "[Task]: Arsitektur Database & Core Services Psikolog Individu, Sesi 30 Menit & Skema Finansial Konfiguratif (apps/backend)",
        "type": "feat",
        "status": "Ready",
        "priority": "Urgent",
        "assignee": "KhoirotunNisa25",
        "body": """## Goal & Scope
Membangun fondasi model data PostgreSQL, migrasi Alembic, dan service domain pada `apps/backend` khusus untuk siklus hidup psikolog profesional mandiri: registrasi, status verifikasi akun, jadwal telekonsultasi 30 menit, dan sistem konfigurasi tarif/bagi hasil yang fleksibel (dikelola via admin web).

## Scope
1. **Model Data PostgreSQL & Alembic Migration**:
   - `PsychologistProfile`: Relasi 1-to-1 dengan `User`, nomor STR, nomor SIP, file dokumen legalitas, spesialisasi klinis, tahun pengalaman, status verifikasi (`PENDING`, `VERIFIED`, `REJECTED`, `NEED_REVISION`), alasan penolakan/catatan admin, data rekening bank (nama bank, nomor rekening, pemilik), dan status kesiapan (`is_online`). Hapus field relasi klinik/faskes mitra.
   - `PsychologistSchedule`: Jam operasional mingguan per hari (Senin-Minggu), durasi slot tetap 30 menit, dan jeda buffer antar sesi. Hapus seluruh atribut alamat/ruang fisik offline.
   - `ConsultationSession`: Relasi pasien (`user_id`), psikolog (`counselor_id`), waktu mulai, waktu selesai (standar 30 menit), status (`SCHEDULED`, `WAITING`, `IN_PROGRESS`, `COMPLETED`, `EXTENDED`, `CANCELLED`), room WebRTC id, dan URL draft SOAP.
   - `PlatformPricingConfig`: Tabel konfigurasi platform untuk tarif per sesi 30 menit (`session_price`), fee platform (`platform_fee_percent`), dan persentase psikolog (`counselor_share_percent`).
   - `CounselorTransaction`: Pencatatan ledger per sesi dengan kolom `gross_amount`, `platform_fee`, `net_amount`, status payout (`PENDING`, `CLEARED`, `WITHDRAWN`), dan referensi sesi.
   - `PayoutRequest`: Pengajuan penarikan dana psikolog ke rekening bank dengan status (`REQUESTED`, `PROCESSING`, `TRANSFERRED`, `REJECTED`).
2. **Endpoints & Service Domain**:
   - `GET /api/v1/counselor/profile` & `PUT /api/v1/counselor/profile`: Profil, STR/SIP, dan update rekening bank.
   - `POST /api/v1/counselor/availability`: Mengubah toggle status online/istirahat.
   - `GET /api/v1/platform/pricing` & `PUT /api/v1/admin/platform/pricing`: Baca & update tarif serta rasio bagi hasil.
   - `GET /api/v1/counselor/finances/summary` & `GET /api/v1/counselor/finances/transactions`: Saldo dan riwayat bagi hasil.
   - `POST /api/v1/counselor/finances/payout`: Mengajukan penarikan saldo dompet ke rekening bank.

## Acceptance Criteria
- [ ] Migrasi Alembic berjalan dan rollback bersih tanpa error.
- [ ] Database menolak entri jadwal dengan atribut offline.
- [ ] Profil psikolog menyimpan status verifikasi dan rekening bank secara valid.
- [ ] Tarif dan bagi hasil dibaca dinamis dari tabel `PlatformPricingConfig` tanpa hardcode angka di service/routes.
- [ ] Mengikuti FastAPI Clean Architecture (Thin Routers 3-5 baris di `app/api/routes/counselor.py`).

## Dependencies & Blockers
- Menjadi prasyarat utama untuk Task Backend #2, Task Mobile #3 & #4, serta Web Portal #6.

## Definition of Done
- [ ] Unit & integration test models dan routes lulus 100% pada `pytest`.
- [ ] Branch mematuhi format `feat/55-backend-counselor-core`.
- [ ] PR menyertakan bukti migrasi dan lulus review.""",
    },
    {
        "title": "[Task]: Engine Penjadwalan Dinamis 30 Menit, Booking Anti-Bentrok & Extension In-Call (apps/backend)",
        "type": "feat",
        "status": "Ready",
        "priority": "High",
        "assignee": "KhoirotunNisa25",
        "body": """## Goal & Scope
Mengembangkan mesin penjadwalan slot telekonsultasi 30 menit dinamis, pencegahan double-booking, mekanisme real-time perpanjangan sesi in-call (+30 menit), serta integrasi pencatatan SOAP pasca-konsultasi.

## Scope
1. **Dynamic 30-Minute Slot Generator & Booking Engine**:
   - `GET /api/v1/counselors/{id}/available-slots?date=YYYY-MM-DD`: Menghitung slot kosong interval 30 menit berdasarkan jam kerja psikolog, buffer istirahat, dan sesi yang sudah terisi.
   - `POST /api/v1/counselors/{id}/book`: Booking sesi 30 menit dengan locking anti-bentrok (`SELECT FOR UPDATE`), alokasi WebRTC room ID, dan pencatatan order transaksi awal.
2. **In-Call Session Extension Engine**:
   - `GET /api/v1/sessions/{session_id}/extension-availability`: Pengecekan real-time apakah psikolog memiliki sesi lain tepat setelah waktu selesai sesi saat ini.
   - `POST /api/v1/sessions/{session_id}/extend`: Memperpanjang sesi berjalan +30 menit (total 60 menit), memperbarui `end_time`, dan mencatat transaksi kedua sesuai tarif platform aktif tanpa memutus room video call.
   - Fallback Payload: Jika psikolog ada janji lain, endpoint mengembalikan status `unavailable` dan daftar slot kosong terdekat berikutnya.
3. **SOAP Clinical Notes & Consent Management**:
   - `GET /api/v1/patients/{id}/clinical-notes` & `POST /api/v1/patients/{id}/clinical-notes`: Menyimpan catatan klinis resmi pasca sesi.
   - `GET /api/v1/patients/{id}/consent-status` & `POST /api/v1/patients/{id}/request-consent`: Pengelolaan izin akses psikolog ke data jurnal & DASS-21 pasien.

## Acceptance Criteria
- [ ] Generator slot 30 menit tidak menghasilkan slot bentrok.
- [ ] Pengecekan perpanjangan sesi akurat: tolak jika jeda ke sesi berikutnya < 30 menit.
- [ ] Sesi yang diperpanjang tetap mempertahankan room ID WebRTC yang sama.
- [ ] Catatan SOAP tersimpan dan terhubung ke riwayat konsultasi pasien.

## Dependencies & Blockers
- Bergantung pada selesainya Issue #1 (Backend Core & Database).

## Definition of Done
- [ ] Pengujian konkurensi booking dan perpanjangan sesi passing di `pytest`.
- [ ] Branch mematuhi format `feat/56-backend-scheduling-extension`.
- [ ] PR menyertakan payload test response extension.""",
    },
    {
        "title": "[Task]: Auth, Gate Verifikasi STR/SIP & Standardisasi Telekonseling (apps/eva_counselor_mobile)",
        "type": "feat",
        "status": "Ready",
        "priority": "High",
        "assignee": "KhoirotunNisa25",
        "body": """## Goal & Scope
Menyempurnakan alur masuk (login/register) psikolog: menerapkan gate status verifikasi akun (Pending, Rejected, Verified), standardisasi telekonseling 30 menit, serta tata kelola akun profesional terverifikasi STR & SIP.

## Scope
1. **Verification Gate & Screen Status Akun**:
   - Buat `VerificationPendingScreen`: Muncul saat psikolog dengan status `PENDING` login. Menjelaskan bahwa dokumen STR & SIP sedang ditinjau Admin Web (1x24 jam), dengan tombol cek status berkala dan hubungi bantuan.
   - Buat `VerificationRejectedScreen`: Menampilkan alasan penolakan dari admin dan tombol untuk mengunggah ulang scan STR/SIP perbaikan.
   - Pasang proteksi route di `AppRouter`: Pengguna dengan status belum terverifikasi tidak dapat mengakses `CounselorMainShellScreen`.
2. **Penyelarasan Registrasi & Login Mobile**:
   - `PsychologistLoginScreen`: Fokus pada autentikasi psikolog profesional terverifikasi.
   - `PsychologistRegistrationScreen`: Kunci durasi ke 30 menit standar platform, wajibkan unggah dokumen STR & SIP untuk verifikasi kredensial.
3. **Standardisasi Telekonseling & UI**:
   - Terapkan branding EVA secara konsisten di seluruh layar dan aset aplikasi.
   - Standardisasi format telekonseling video call 30 menit dengan buffer istirahat terkonfigurasi.
4. **Tata Kelola Layanan Konseling Digital**:
   - Fokus 100% pada layanan telekonseling daring.
   - Refactor `PsychologistUserEntity`: Sesuaikan atribut profil profesional dengan model backend.

## Acceptance Criteria
- [ ] Akun pending diarahkan ke `VerificationPendingScreen` dan tidak bisa masuk ke dashboard konsultasi.
- [ ] Registrasi psikolog terfokus murni pada individu profesional dengan unggah STR/SIP.
- [ ] `flutter analyze` bersih dengan 0 issues.
- [ ] Seluruh unit dan widget test lulus pengujian.

## Dependencies & Blockers
- Dapat dikerjakan paralel dengan Task Backend #1.

## Definition of Done
- [ ] Alur registrasi ➔ login ➔ pending gate ➔ approved teruji di emulator/HP.
- [ ] Branch mematuhi format `feat/57-counselor-auth-verification-gate`.
- [ ] PR menyertakan screenshot layar status verifikasi baru.""",
    },
    {
        "title": "[Task]: Siklus Konsultasi Lengkap: In-Call Extension, Draf SOAP AI & Payout Dompet (apps/eva_counselor_mobile)",
        "type": "feat",
        "status": "Ready",
        "priority": "High",
        "assignee": "KhoirotunNisa25",
        "body": """## Goal & Scope
Menuntaskan alur kerja psikolog saat konsultasi hingga pasca-konsultasi: penanganan dialog perpanjangan sesi in-call (+30 menit), integrasi draf catatan klinis SOAP dari transkripsi Eva AI, serta pengelolaan rekening bank dan penarikan saldo dompet (payout).

## Scope
1. **Pengaturan Jadwal Dinamis 30 Menit**:
   - Tampilan pengaturan jam kerja di `counselor_schedule_settings_screen.dart`: Pilih hari kerja aktif, jam mulai - jam selesai, dan jeda buffer antar sesi (5-10 menit).
   - Sinkronisasi toggle online/istirahat di top bar home screen ke `POST /api/v1/counselor/availability`.
   - Perbarui tampilan kalender beranda dari slot 50 menit menjadi kelipatan 30 menit.
2. **In-Call Extension UI & Timer Sync**:
   - Di `VideoConsultationScreen`, tangani sinyal saat pasien meminta tambah sesi di menit ke-25.
   - Tampilkan modal konfirmasi interaktif: *"Pasien ingin memperpanjang konsultasi (+30 menit). Terima perpanjangan?"*
   - Jika disetujui: Panggil backend `POST /sessions/{id}/extend`, perbarui timer dari 30:00 menjadi 60:00 tanpa putus panggilan.
   - Jika ditolak: Kirim respons penolakan agar pasien diarahkan booking sesi berikutnya.
3. **Alur Pasca-Konsultasi & Verifikasi Draf SOAP**:
   - Setelah panggilan berakhir, otomatis arahkan psikolog ke form rekam medis SOAP di `patient_detail_consent_screen.dart`.
   - Tombol "Muat Draf SOAP Eva AI": Memuat ringkasan otomatis hasil transkrip percakapan ke kolom SOAP (Subjective, Objective, Assessment, Plan).
   - Simpan catatan klinis resmi ke backend (`POST /patients/{id}/clinical-notes`).
4. **Dompet Finansial & Penarikan Dana (Payout)**:
   - Hubungkan `TransactionHistoryScreen` ke API backend: Tampilkan saldo aktif, rincian bagi hasil per sesi 30 menit, dan potongan fee platform secara transparan.
   - Modal Pengaturan Rekening Bank (`counselor_bank_account_modal.dart`): Simpan bank, nomor rekening, dan nama pemilik.
   - Tombol dan dialog "Tarik Saldo (Request Payout)" untuk mencairkan penghasilan ke rekening bank terdaftar.
5. **Harmonisasi Fitur Pendukung Profil**:
   - Pastikan Google Drive Backup (`counselor_drive_backup_modal.dart`), Kredensial STR (`counselor_str_credentials_modal.dart`), Sertifikat SKP (`counselor_certificates_modal.dart`), Ulasan Pasien (`counselor_reviews_modal.dart`), dan SOP De-eskalasi Krisis (`counselor_guidelines_modal.dart`) tetap berfungsi harmonis.

## Acceptance Criteria
- [ ] Psikolog dapat menerima perpanjangan sesi in-call dan timer bertambah menjadi 60 menit secara real-time.
- [ ] Draf SOAP otomatis dari Eva AI dapat diedit dan tersimpan di riwayat pasien.
- [ ] Pengajuan penarikan dana berhasil terkirim ke backend dan status transaksi tercatat rapi.
- [ ] Seluruh remote datasource (`RemoteAuthDataSource`, `RemotePatientDataSource`, `RemoteFinanceDataSource`, `RemoteVideoCallDataSource`) terhubung ke Live API.

## Dependencies & Blockers
- Bergantung pada ketersediaan endpoint dari Task #1 dan #2.

## Definition of Done
- [ ] Video demo pengujian end-to-end (terima perpanjangan sesi, edit SOAP, dan request payout) disertakan dalam PR.
- [ ] Branch mematuhi format `feat/58-counselor-session-soap-payout`.
- [ ] Lulus pengujian integrasi.""",
    },
    {
        "title": "[Task]: Penyelarasan Booking Konsultasi Pasien: Hapus Mitra/Offline, Sesi Paten 30 Menit Dinamis & Fitur Tambah Sesi In-Call (apps/eva_mobile)",
        "type": "feat",
        "status": "Ready",
        "priority": "High",
        "assignee": "ekyaaa",
        "body": """## Goal & Scope
Menyelaraskan alur konsultasi pada aplikasi pasien (`apps/eva_mobile`): menghapus kartu klinik dan opsi tatap muka/offline, memperbarui lembar booking ke slot dinamis paten 30 menit dengan tarif platform yang diambil dinamis dari backend, serta menambahkan tombol dan alur perpanjangan sesi konsultasi (+30 menit) saat video call berlangsung.

## Scope
1. **Pembersihan Modul Faskes/Mitra & Konsultasi Offline**:
   - Hapus komponen `clinic_card.dart` dan `clinic_location_map_card.dart` dari `CareScreen`.
   - Hapus filter klinik dan pilihan konsultasi "Tatap Muka / Offline" di `BookingConsultationSheet` (layanan 100% telekonsultasi online).
   - Tampilkan psikolog individu profesional dengan badge sertifikasi STR/SIP dan tarif sesi 30 menit (diambil dari API `GET /api/v1/platform/pricing`).
2. **Booking Dinamis Sesi 30 Menit**:
   - Perbarui time picker di `BookingConsultationSheet` agar mengambil slot tersedia 30 menit dari endpoint `GET /api/v1/counselors/{id}/available-slots`.
3. **Fitur Tambah Sesi In-Call (+30 Menit) & Fallback**:
   - Di `PsychologistVideoCallScreen`, tambahkan banner/tombol "Tambah Sesi (+30 Menit)" yang aktif saat waktu tersisa <= 5 menit.
   - Panggil `GET /api/v1/sessions/{id}/extension-availability`.
   - **Skenario 1 (Psikolog Available)**: Tampilkan modal konfirmasi pembayaran perpanjangan sesi dan tunggu persetujuan psikolog; jika disetujui, perpanjang timer video call menjadi 60 menit.
   - **Skenario 2 (Psikolog Not Available / Sibuk)**: Tampilkan bottom sheet ramah: *"Mohon maaf, psikolog memiliki janji konsultasi lain setelah ini"*, disertai tombol langsung *"Jadwalkan Sesi Berikutnya"* yang membuka kalender slot kosong psikolog tersebut.

## Acceptance Criteria
- [ ] Seluruh tampilan daftar care di Eva Mobile berfokus pada individu profesional (tanpa klinik/mitra fisik).
- [ ] Pemilihan waktu booking presisi pada interval 30 menit sesuai ketersediaan dinamis.
- [ ] Tarif konsultasi tidak di-hardcode di kode mobile, melainkan mengambil data dari endpoint backend.
- [ ] Tombol tambah sesi in-call berfungsi dengan handling kedua skenario (berhasil perpanjang atau pengalihan ke booking sesi berikutnya).
- [ ] `flutter analyze` pada `apps/eva_mobile` bersih tanpa warning baru.

## Dependencies & Blockers
- Koordinasi kontrak endpoint dengan `@KhoirotunNisa25` (Issue #2).

## Definition of Done
- [ ] Alur booking dan in-call extension teruji lancar di emulator / perangkat fisik.
- [ ] Branch mematuhi format `feat/59-patient-dynamic-booking-extension`.
- [ ] PR menyertakan rekaman demonstrasi in-call extension.""",
    },
    {
        "title": "[Task]: Pendaftaran & Verifikasi Psikolog, Pengaturan Master Tarif/Bagi Hasil & Monitoring Sesi (apps/web)",
        "type": "feat",
        "status": "Ready",
        "priority": "High",
        "assignee": "Oktavian19",
        "body": """## Goal & Scope
Mengembangkan antarmuka pendaftaran & verifikasi kredensial psikolog individu profesional di portal web, menyediakan halaman pengaturan master sistem Eva (penentuan tarif per sesi 30 menit dan persentase bagi hasil), serta menyelaraskan monitoring jadwal sesi online (termasuk status sesi yang diperpanjang) dan menghilangkan pendaftaran mitra faskes institusi.

## Scope
1. **Pendaftaran & Verifikasi Psikolog Mandiri (`apps/web`)**:
   - Ubah orientasi pendaftaran di portal web dari formulir institusi faskes/klinik menjadi pendaftaran **Psikolog Profesional Individu**.
   - Halaman review & verifikasi di Admin Portal (`/admin/psychologists`): preview dokumen STR/SIP, input catatan verifikasi, dan tombol aksi `Approve` / `Reject` (yang otomatis memperbarui status verifikasi akun di mobile).
2. **Modul Pengaturan Master Sistem (Tarif & Skema Bagi Hasil)**:
   - Sediakan halaman/tab **Pengaturan Platform Eva** di Admin Portal (`/admin/settings`):
     - Input tarif dasar per sesi 30 menit.
     - Input persentase bagi hasil (hak psikolog vs platform).
     - Tombol simpan yang memanggil `PUT /api/v1/admin/platform/pricing`.
   - Tampilkan kalkulator preview estimasi nominal pembagian hasil secara transparan untuk memudahkan tim mendiskusikan dan menetapkan angka final.
3. **Monitoring Jadwal & Sesi 30 Menit Read-Only**:
   - Pastikan tabel monitoring di Admin menampilkan durasi sesi standar (30 Menit) dan status perpanjangan (`Diperpanjang: 60 Menit`).
   - Hapus kolom atau badge lokasi tatap muka/offline.

## Acceptance Criteria
- [ ] Web Portal memiliki formulir pendaftaran dan panel verifikasi kredensial psikolog individu (STR/SIP) yang lengkap.
- [ ] Admin Portal memiliki antarmuka pengaturan tarif per sesi 30 menit dan persentase bagi hasil yang terhubung ke backend.
- [ ] Halaman monitoring jadwal menampilkan durasi 30 menit dan status perpanjangan secara presisi tanpa embel-embel offline.
- [ ] `npm run lint` dan `npm run build` di `apps/web` lulus tanpa error.

## Dependencies & Blockers
- Menjadi landasan penetapan tarif final bersama tim melalui panel admin web.

## Definition of Done
- [ ] Build produksi web sukses (`npm run build`).
- [ ] Branch mematuhi format `feat/60-web-psychologist-verification-settings`.
- [ ] PR menyertakan demonstrasi antarmuka verifikasi psikolog dan pengaturan tarif.""",
    },
]

def main(dry_run: bool = False):
    print(f"=== {'DRY RUN: ' if dry_run else ''}Processing {len(ISSUES)} GitHub Issues ===")
    for idx, iss in enumerate(ISSUES, 1):
        print(f"\n--- [{idx}/{len(ISSUES)}] {iss['title']} ---")
        try:
            create_issue(
                title=iss["title"],
                body=iss["body"],
                issue_type=iss["type"],
                priority=iss["priority"],
                status=iss["status"],
                assignee=iss["assignee"],
                dry_run=dry_run,
            )
        except Exception as e:
            print(f"❌ Error creating issue {idx}: {e}")
            if not dry_run:
                sys.exit(1)
    print("\n✅ All issues processed successfully!")

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true", help="Preview only")
    args = parser.parse_args()
    main(dry_run=args.dry_run)
