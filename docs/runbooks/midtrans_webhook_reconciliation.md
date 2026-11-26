# Runbook: Rekonsiliasi Pembayaran Midtrans QRIS & Payout Iris

> Berlaku untuk sistem pembayaran `#136` (`POST /api/v1/webhooks/midtrans/payment`, `POST /api/v1/webhooks/midtrans/iris`, ARQ worker, dan portal admin `/admin/finance`).

## 1. Kegagalan Webhook Midtrans QRIS (`C2 / C6`)
1. **Gejala:** User telah membayar di aplikasi e-wallet/bank, namun status order di aplikasi masih `pending` atau masuk ke status `review_required`.
2. **Pemeriksaan Awal:**
   - Periksa tabel `payment_webhook_inbox` untuk `provider = 'midtrans_qris'` (`process_status`, `signature_valid`, `last_error`).
   - Pastikan `MIDTRANS_SIGNATURE_SECRET_KEY` di environment sama dengan Merchant Server Key yang dipakai Midtrans untuk menghitung `signature_key`.
   - Periksa hasil ARQ task `payment_reconcile_pending_orders_task` & `payment_retry_outbox_task`.
3. **Pemulihan Manual Aman:**
   - Jalankan on-demand refresh lewat endpoint `POST /api/v1/coins/topups/{id}/refresh` atau `ReconciliationService.run_daily_reconciliation()`.
   - Sistem akan memanggil `GET /v2/{order_id}/status` ke Midtrans; jangan pernah mengkreditkan `User.coin_balance` langsung lewat SQL tanpa row `CoinTopupOrder` + `CoinTransaction`.

## 2. Kegagalan / Timeout Payout Iris (`C4 / C6`)
1. **Gejala:** Penarikan honorarium psikolog tertahan di `waiting_approval`, `processing`, atau `review_required`.
2. **Pemeriksaan Awal:**
   - Cek `counselor_withdrawals` (`status`, `provider_reference`, `reconciliation_status`) dan `counselor_withdrawal_events`.
   - Pastikan `PsychologistProfile.locked_withdrawal_balance` konsisten dengan jumlah `wallet_debit_idr` dari penarikan aktif (`requested | waiting_approval | processing | review_required`).
3. **Pemulihan:**
   - Worker `payout_reconcile_pending_withdrawals_task` melakukan polling `GET /payouts/{reference_no}` menggunakan Creator Key Iris dan memicu `/api/v1/webhooks/midtrans/iris`.
   - Bila Iris mengembalikan status `failed`, `rejected`, `cancelled`, atau `reversed`, `PayoutService.apply_authoritative_status()` akan melepas `locked_withdrawal_balance` dan mengembalikan saldo ke `wallet_balance` secara idempoten.

## 3. Ketidaksesuaian Rekonsiliasi (`unreconciled_count > 0`)
- Buka endpoint `GET /api/v1/admin/finance/summary` dan filter `GET /api/v1/admin/finance/transactions?status=review_required`.
- Bandingkan `provider_reference` dengan mutasi Dashboard Midtrans/Iris sebelum melakukan koreksi operasional.
