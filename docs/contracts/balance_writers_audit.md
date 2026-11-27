# Audit Matrix: Penulis Saldo (`User.coin_balance` & `PsychologistProfile.wallet_balance`)

> **Scope:** `apps/backend/api/app/` (Baseline commit `d2a2019` / `origin/main`)  
> **Tujuan:** Memetakan seluruh mutasi saldo koin user dan honorarium psikolog untuk mencegah *double debit*, *writer paralel*, maupun *premature withdrawal* sebelum integrasi Midtrans QRIS & Iris Payout.

---

## 1. Penulis Saldo `User.coin_balance` (Integer EVA Coin)

| Lokasi & Simbol | Operasi Saat Ini | Lock & Ledger Saat Ini | Temuan & Rencana Perbaikan |
| :--- | :--- | :--- | :--- |
| `apps/backend/api/app/services/auth/auth_service.py` (`AuthService.register`, L126) | Mengisi `coin_balance = initial_free_coins` dari `CoinEconomyConfig` | Tidak ada `CoinTransaction` audit record saat registrasi | Pertahankan kompatibilitas trial; catat grant trial awal di ledger bila kebijakan audit membutuhkan (non-cash). |
| `apps/backend/api/app/services/coin/coin_service.py` (`CoinService.topup_user_coins`, L122) | Menambah `user.coin_balance += coins_granted` | Memakai `SELECT ... FOR UPDATE` (`L96`) dan membuat `CoinTransaction` (`TOPUP_ADMIN` / `GRANT_ADMIN`) | Pertahankan kompatibilitas penuh; pisahkan dari cash flow QRIS di C5 Admin Finance. |
| `apps/backend/api/app/services/session/scheduling_service.py` (`book_session` L249, `extend_session` L422, `_lock_and_validate_patient_coins` L470, `_record_patient_coin_debit` L494) | Mengurangi `patient.coin_balance -= coins_debit` | Memakai `SELECT ... FOR UPDATE` dan membuat `CoinTransaction` (`BOOKING_DEBIT` / `EXTENSION_DEBIT`) | Pastikan pesan error tidak mengarahkan hanya ke Admin EVA saat QRIS aktif; tambah alur atomik refund `CoinTransaction(REFUND)` saat sesi dibatalkan sebelum dimulai. |
| `apps/backend/api/app/services/call/billing_service.py` (`CallBillingService.charge_call_minute`) | Mengurangi `user.coin_balance -= coins_cost` (default 1 Koin/menit auto-debit saat Telepon AI EVA) | Memakai `SELECT ... FOR UPDATE` pada `User` dan membuat `CoinTransaction` (`AI_CALL_DEBIT`) | Wajib JWT auth di WebSocket pada semua mode termasuk `privacy_mode=local_private` (zero-DB-write tetap dijaga untuk transkrip/diary). |
| **Baru (Fase 2):** `CoinTopupService` (webhook settlement / status sync) | Kredit `user.coin_balance += total_coins_snapshot` | Wajib `SELECT ... FOR UPDATE` pada `CoinTopupOrder` & `User` + `CoinTransaction(TOPUP_QRIS)` | Kredit tepat 1x (idempotent via `coin_transaction_id` & status guard `paid`). |
| `apps/backend/api/app/db/seed.py` (L77, L102) | Seeding user awal dev/demo | Hanya saat seed DB kosong/dev | Tidak aktif di production (`APP_ENV=production`). |

---

## 2. Penulis Saldo `PsychologistProfile.wallet_balance` (IDR `Numeric(14, 2)`)

| Lokasi & Simbol | Operasi Saat Ini | Lock & Ledger Saat Ini | Temuan & Rencana Perbaikan |
| :--- | :--- | :--- | :--- |
| `apps/backend/api/app/services/session/scheduling_service.py` (`book_session`, L289–302) | Langsung menambah `counselor.wallet_balance += counselor_share` dan mencatat `CounselorTransaction(EARNING, COMPLETED)` saat booking | Tidak memakai `with_for_update()` pada `PsychologistProfile`; honorarium langsung *available* sebelum sesi selesai | **Risiko:** Konselor bisa menarik honorarium sebelum sesi berjalan/selesai. **Perbaikan Fase 2:** Catat `CounselorTransaction(EARNING, PENDING)` saat booking (masuk ke `pending_clearing_balance` di `GET /finances/summary`) dan lepaskan ke `wallet_balance` + `COMPLETED` saat sesi `completed` (atau batalkan/refund jika `cancelled`). |
| `apps/backend/api/app/services/session/scheduling_service.py` (`extend_session`, L447–464) | Langsung menambah `counselor.wallet_balance += ext_counselor` dengan `COMPLETED` | Tidak memakai `with_for_update()` pada `PsychologistProfile` (`L459`) | **Perbaikan Fase 2:** Gunakan `with_for_update()` pada `PsychologistProfile`; ikuti pola `PENDING` hingga sesi `completed` (atau release saat `completed` untuk semua `EARNING` `PENDING` milik `session_id`). |
| `apps/backend/api/app/services/care/care_service.py` (`update_call_status`, L151–169) | Mengubah status sesi ke `LIVE`, `COMPLETED`, atau `CANCELLED` | Tidak memanggil clearing honorarium atau refund koin saat `COMPLETED` / `CANCELLED` | **Perbaikan Fase 2:** Panggil service clearing / cancellation atomik (idempotent) ketika sesi transisi ke `COMPLETED` atau `CANCELLED` (dan pada `save_soap_notes` bila melengkapi sesi). |
| `apps/backend/api/app/services/finances/finance_service.py` (`request_payout`, L140–185) | Langsung mengurangi `profile.wallet_balance -= withdraw_amount` | Tidak memakai `with_for_update()`, tidak ada `locked_withdrawal_balance`, tidak ada quote/fee/rekening verified | **Perbaikan Fase 4:** Tolak/deprekasi bypass di `POST /finances/payout`; gunakan `POST /finances/payouts` dengan `with_for_update()`, pindah `wallet_balance` → `locked_withdrawal_balance`, dan kompensasi aman saat gagal/reversed. |
| `apps/backend/api/app/db/seed.py` (L646–799) | Seeding profil psikolog dev | Hanya saat seed awal | Tetap aman untuk dev seed. |
