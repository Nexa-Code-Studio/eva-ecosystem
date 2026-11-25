import assert from 'node:assert/strict'
import test from 'node:test'
import {
  mapBackendFinanceSummaryToDomain,
  mapBackendFinanceTransactionDetailToDomain,
  mapBackendFinanceTransactionsPageToDomain,
} from '../../src/services/contracts/financeMappers.ts'
import {
  formatIdrOrUnavailable,
  formatTimestampWib,
  parseBackendErrorDetail,
  wibDateRangeToUtc,
} from '../../src/services/contracts/financeUtils.ts'

test('wibDateRangeToUtc converts WIB calendar dates into half-open UTC [from, to)', () => {
  const range = wibDateRangeToUtc('2026-11-01', '2026-11-30')
  assert.equal(range.from, '2026-10-31T17:00:00.000Z')
  assert.equal(range.to, '2026-11-30T17:00:00.000Z')
})

test('formatIdrOrUnavailable keeps real 0 distinct from null/undefined', () => {
  assert.equal(formatIdrOrUnavailable(0), 'Rp0')
  assert.equal(formatIdrOrUnavailable(150000), 'Rp150.000')
  assert.equal(formatIdrOrUnavailable(null), 'Tidak tersedia')
  assert.equal(formatIdrOrUnavailable(undefined), 'Tidak tersedia')
})

test('formatTimestampWib formats UTC timestamps in WIB zone', () => {
  const formatted = formatTimestampWib('2026-11-25T02:00:00.000Z')
  assert.match(formatted, /25 Nov 2026/)
  assert.match(formatted, /09:00 WIB$/)
  assert.equal(formatTimestampWib(null), 'Tidak tersedia')
})

test('parseBackendErrorDetail parses C1 structured envelope and string fallbacks', () => {
  const nested = parseBackendErrorDetail(403, {
    detail: { code: 'FORBIDDEN_ADMIN', message: 'Khusus admin keuangan' },
  })
  assert.deepEqual(nested, { code: 'FORBIDDEN_ADMIN', message: 'Khusus admin keuangan' })

  const flat = parseBackendErrorDetail(400, { detail: 'Parameter tanggal tidak valid' })
  assert.deepEqual(flat, { code: null, message: 'Parameter tanggal tidak valid' })

  const unauth = parseBackendErrorDetail(401, null)
  assert.equal(unauth.code, 'UNAUTHORIZED')
})

test('mapBackendFinanceSummaryToDomain preserves null unknown provider fields', () => {
  const mapped = mapBackendFinanceSummaryToDomain({
    currency: 'IDR',
    from: '2026-11-01T00:00:00Z',
    to: '2026-12-01T00:00:00Z',
    money_in_paid_idr: 15000000,
    money_in_pending_idr: 500000,
    money_out_completed_idr: 8500000,
    money_out_pending_idr: 750000,
    refund_completed_idr: 100000,
    provider_fees_known_idr: null,
    commission_earned_idr: 2250000,
    client_credit_liability_idr: 1500000,
    counselor_payable_idr: 750000,
    unreconciled_count: 2,
    provider_payout_available_idr: null,
    provider_balance_as_of: null,
  })

  assert.equal(mapped.providerFeesKnownIdr, null)
  assert.equal(mapped.providerPayoutAvailableIdr, null)
  assert.equal(mapped.providerBalanceAsOf, null)
  assert.equal(mapped.moneyInPaidIdr, 15000000)
  assert.equal(mapped.unreconciledCount, 2)
})

test('finance transaction mappers handle null fees, unknown reconciliation status, and events timeline', () => {
  const page = mapBackendFinanceTransactionsPageToDomain({
    items: [
      {
        id: 'tx-1',
        direction: 'in',
        source: 'qris_topup',
        reference_id: 'EVA-TOPUP-001',
        provider_reference: 'prov-1',
        actor_label: 'User U-001',
        amount_idr: 50000,
        fee_idr: null,
        net_amount_idr: null,
        currency: 'IDR',
        status: 'paid',
        reconciliation_status: 'unexpected_status_from_future',
        created_at: '2026-11-25T02:00:00Z',
        completed_at: '2026-11-25T02:05:00Z',
        bank_account_masked: null,
      },
    ],
    page: 1,
    page_size: 20,
    total: 1,
  })

  assert.equal(page.items[0].feeIdr, null)
  assert.equal(page.items[0].netAmountIdr, null)
  assert.equal(page.items[0].walletDebitIdr, null)
  assert.equal(page.items[0].reconciliationStatus, 'unknown')

  const detail = mapBackendFinanceTransactionDetailToDomain({
    ...{
      id: 'tx-2',
      direction: 'out',
      source: 'counselor_payout',
      reference_id: 'EVA-PO-01',
      provider_reference: 'iris-1',
      actor_label: 'Psikolog A',
      amount_idr: 300000,
      fee_idr: 5000,
      net_amount_idr: 295000,
      wallet_debit_idr: 300000,
      currency: 'IDR',
      status: 'waiting_approval',
      reconciliation_status: 'mismatch',
      created_at: '2026-11-25T02:00:00Z',
      completed_at: null,
      bank_account_masked: 'BCA **** 1234',
    },
    events: [
      {
        status: 'waiting_approval',
        occurred_at: '2026-11-25T02:01:00Z',
        source: 'iris',
        message: 'Menunggu approval di Iris Dashboard',
      },
    ],
  })

  assert.equal(detail.reconciliationStatus, 'mismatch')
  assert.equal(detail.walletDebitIdr, 300000)
  assert.equal(detail.bankAccountMasked, 'BCA **** 1234')
  assert.equal(detail.events.length, 1)
  assert.equal(detail.events[0].source, 'iris')
})
