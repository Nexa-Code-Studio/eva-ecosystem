import assert from 'node:assert/strict'
import test from 'node:test'
import {
  MOCK_FINANCE_TRANSACTIONS,
  queryMockFinanceSummary,
  queryMockFinanceTransactionDetail,
  queryMockFinanceTransactions,
} from '../../src/data/mock/financeMetrics.mock.ts'
import { wibDateRangeToUtc } from '../../src/services/contracts/financeUtils.ts'

test('mock finance summary excludes pending/expired QRIS from moneyInPaidIdr', () => {
  const { from, to } = wibDateRangeToUtc('2026-11-01', '2026-11-30')
  const summary = queryMockFinanceSummary({ from, to })

  // Paid QRIS fixtures: 100,000 + 50,000 + 150,000 = 300,000; Pending = 25,000; Expired excluded
  assert.equal(summary.moneyInPaidIdr, 300000)
  assert.equal(summary.moneyInPendingIdr, 25000)
  assert.equal(summary.moneyOutCompletedIdr, 450000)
  assert.equal(summary.moneyOutPendingIdr, 300000)
  assert.equal(summary.refundCompletedIdr, 50000)
  assert.equal(summary.unreconciledCount, 2)
})

test('mock finance queries support direction, status, source, search q, and server pagination', () => {
  const { from, to } = wibDateRangeToUtc('2026-11-01', '2026-11-30')

  const moneyIn = queryMockFinanceTransactions({
    from,
    to,
    direction: 'in',
    page: 1,
    pageSize: 2,
  })
  assert.equal(moneyIn.total, 5)
  assert.equal(moneyIn.items.length, 2)
  assert.ok(moneyIn.items.every((tx) => tx.source === 'qris_topup'))

  const payouts = queryMockFinanceTransactions({
    from,
    to,
    direction: 'out',
    source: 'counselor_payout',
    page: 1,
    pageSize: 10,
  })
  assert.equal(payouts.total, 2)
  assert.ok(payouts.items.every((tx) => !tx.bankAccountMasked || tx.bankAccountMasked.includes('****')))

  const searched = queryMockFinanceTransactions({
    from,
    to,
    q: 'EVA-REV-20261119-001',
    page: 1,
    pageSize: 10,
  })
  assert.equal(searched.total, 1)
  assert.equal(searched.items[0].reconciliationStatus, 'review_required')
})

test('every mock finance detail keeps bank accounts masked and provides timeline events', () => {
  for (const row of MOCK_FINANCE_TRANSACTIONS) {
    const detail = queryMockFinanceTransactionDetail(row.id)
    assert.ok(detail.events.length >= 1)
    if (detail.bankAccountMasked) {
      assert.match(detail.bankAccountMasked, /\*{4}/)
    }
  }
})
