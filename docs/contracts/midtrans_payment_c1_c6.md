# Kontrak API Pembayaran Midtrans QRIS & Payout (`C1–C6`, v1)

> **Prefix:** `/api/v1` | **Status:** Contract v1 (Selaras dengan `#135`, `#136`, `#137`/PR `#139`, dan `#138`)

## C1. Konvensi Global
- **Auth:** Bearer JWT (`Authorization: Bearer <token>`); identitas diambil dari token, bukan dari body client.
- **Format:** JSON `snake_case`, ID string opaque, timestamp UTC ISO 8601 (`...Z`), `currency: "IDR"`, nomor rekening bertipe `string` dan selalu *masked* di semua response (`****3333`).
- **Pagination:** `{ "items": [...], "page": 1, "page_size": 20, "total": 0 }` (`page_size` max `100`), diurutkan `created_at desc, id desc`.
- **Error Envelope:** `{ "detail": { "code": "ERROR_CODE", "message": "Pesan ramah pengguna" } }`.
- **Idempotency-Key:** Wajib pada `POST /coins/topups` dan `POST /finances/payouts`. Replay payload identik mengembalikan order/payout yang sama (`200`), sedangkan payload berbeda dengan key sama mengembalikan `409 IDEMPOTENCY_CONFLICT`.

## C2. Client EVA Coin & QRIS (`apps/eva_mobile`)
- `GET /coins/packages` — Daftar paket aktif (`CoinPackageResponse[]`).
- `GET /coins/economy` — Konfigurasi kurs & free trial (`CoinEconomyConfigResponse`).
- `GET /users/coins` — Saldo koin aktif (`{user_id, coin_balance}`).
- `POST /coins/topups` — Buat order QRIS (`{package_id}` + header `Idempotency-Key`).
- `GET /coins/topups` — Riwayat order top-up milik user (paginated).
- `GET /coins/topups/{id}` — Detail status order top-up milik user.
- `GET /coins/topups/{id}/qr` — Proxy gambar PNG QRIS (`Cache-Control: private, no-store`, owner-only, host allowlist).
- `POST /coins/topups/{id}/refresh` — Sinkronisasi status on-demand ke Midtrans (rate-limited).
- Status valid: `creating | pending | paid | expired | failed | cancelled | refund_pending | partially_refunded | refunded | review_required`.
- Error codes: `PACKAGE_INACTIVE`, `TOPUP_NOT_FOUND`, `PROVIDER_UNAVAILABLE`, `IDEMPOTENCY_CONFLICT`, `PAYMENT_DISABLED`.

## C3. Rekening Bank Psikolog (`apps/eva_counselor_mobile`, Terverifikasi dengan PR `#139`)
- `GET /finances/banks` — `{ "items": [{ "code": "mandiri", "name": "Bank Mandiri" }] }`.
- `POST /finances/bank-accounts/validate` — Input `{bank_code, account_number}`, output `BankValidation` (`validation_id`, `account_holder_name`, `account_number_masked`, `status`, `name_match`, `expires_at`).
- `GET /finances/bank-accounts/current` — `{ "bank_account": BankAccount | null }`.
- `PUT /finances/bank-accounts/current` — Input `{validation_id}` (+ reauth guard), output `BankAccount` (atau `{bank_account: BankAccount}`).
- Error codes: `BANK_NOT_SUPPORTED`, `ACCOUNT_NOT_FOUND`, `BANK_NAME_MISMATCH`, `VALIDATION_EXPIRED`, `BANK_UNVERIFIED`, `REAUTH_REQUIRED`, `PROVIDER_UNAVAILABLE`.

## C4. Honorarium & Payout Psikolog (`apps/eva_counselor_mobile`, Terverifikasi dengan PR `#139`)
- `GET /finances/summary` — `available_balance`, `pending_clearing_balance`, `locked_withdrawal_balance`, `total_earnings_this_month`, `total_withdrawn`, `currency`.
- `GET /finances/transactions` — Riwayat transaksi (masked bank info + optional `transaction_type`, `payout_status`).
- `GET /finances/payout-policy` — `{min_amount_idr, max_amount_idr, fee_idr, fee_bearer, currency, payout_enabled}`.
- `POST /finances/payouts/quote` — Input `{bank_account_id, amount_idr}`, output `PayoutQuote` (tanpa lock saldo).
- `POST /finances/payouts` — Input `{quote_id}` + header `Idempotency-Key`, output `Payout`.
- `GET /finances/payouts` & `GET /finances/payouts/{id}` — Paginated list & detail payout.
- Status valid: `requested | waiting_approval | processing | completed | failed | rejected | cancelled | reversed | review_required`.
- Error codes: `INSUFFICIENT_BALANCE`, `BANK_UNVERIFIED`, `PAYOUT_DISABLED`, `PAYOUT_LIMIT`, `QUOTE_EXPIRED`, `ACCOUNT_CHANGED`, `IDEMPOTENCY_CONFLICT`, `PROVIDER_UNAVAILABLE`.

## C5. Admin Finance Portal (`apps/web`, `#138`)
- `GET /admin/finance/summary?from=&to=` — KPI money-in/out terpisah dari admin grant (`null` bila provider fee/balance unknown).
- `GET /admin/finance/transactions?from=&to=&direction=&status=&source=&q=&page=&page_size=` — Paginated `FinanceTransaction[]`.
- `GET /admin/finance/transactions/{id}` — `FinanceTransaction` + `events[]` ter-sanitasi.

## C6. Provider Webhooks (Backend-Only)
- `POST /api/v1/webhooks/midtrans/payment` — SHA512(`MIDTRANS_SIGNATURE_SECRET_KEY`) + `GET /v2/{order_id}/status` + idempotent ledger credit.
- `POST /api/v1/webhooks/midtrans/iris` — Iris verification + `GET /payouts/{reference_no}` + idempotent state/unlock mutation.
