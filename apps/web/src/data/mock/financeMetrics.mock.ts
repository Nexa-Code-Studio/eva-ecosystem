import type {
  FinanceSummary,
  FinanceTransactionDetail,
  FinanceTransactionsQuery,
  PaginatedFinanceTransactions,
} from '../../types/domain/finance.ts'

export const MOCK_FINANCE_TRANSACTIONS: FinanceTransactionDetail[] = [
  {
    id: 'fin-qris-001',
    direction: 'in',
    source: 'qris_topup',
    referenceId: 'EVA-QRIS-20261125-001',
    providerReference: 'midtrans-ord-990182',
    actorLabel: 'Raka Pratama (U-104)',
    amountIdr: 100000,
    feeIdr: 700,
    netAmountIdr: 99300,
    walletDebitIdr: null,
    currency: 'IDR',
    status: 'paid',
    reconciliationStatus: 'matched',
    createdAt: '2026-11-25T02:15:00.000Z',
    completedAt: '2026-11-25T02:16:12.000Z',
    bankAccountMasked: null,
    events: [
      {
        status: 'pending',
        occurredAt: '2026-11-25T02:15:00.000Z',
        source: 'backend',
        message: 'Tagihan QRIS dibuat untuk Paket 110 Koin',
      },
      {
        status: 'paid',
        occurredAt: '2026-11-25T02:16:10.000Z',
        source: 'midtrans',
        message: 'Notifikasi settlement QRIS diterima',
      },
      {
        status: 'matched',
        occurredAt: '2026-11-25T02:20:00.000Z',
        source: 'reconciler',
        message: 'Nominal settlement cocok dengan kredit ledger koin',
      },
    ],
  },
  {
    id: 'fin-qris-002',
    direction: 'in',
    source: 'qris_topup',
    referenceId: 'EVA-QRIS-20261124-019',
    providerReference: 'midtrans-ord-990164',
    actorLabel: 'Dinda Kirana (U-219)',
    amountIdr: 50000,
    feeIdr: null,
    netAmountIdr: null,
    walletDebitIdr: null,
    currency: 'IDR',
    status: 'paid',
    reconciliationStatus: 'mismatch',
    createdAt: '2026-11-24T13:10:00.000Z',
    completedAt: '2026-11-24T13:11:45.000Z',
    bankAccountMasked: null,
    events: [
      {
        status: 'pending',
        occurredAt: '2026-11-24T13:10:00.000Z',
        source: 'backend',
        message: 'Tagihan QRIS dibuat untuk Paket 50 Koin',
      },
      {
        status: 'paid',
        occurredAt: '2026-11-24T13:11:45.000Z',
        source: 'midtrans',
        message: 'Pembayaran settlement tercatat tanpa laporan biaya MDR',
      },
      {
        status: 'mismatch',
        occurredAt: '2026-11-24T14:00:00.000Z',
        source: 'reconciler',
        message: 'Selisih laporan fee provider memerlukan pengecekan read-only',
      },
    ],
  },
  {
    id: 'fin-qris-003',
    direction: 'in',
    source: 'qris_topup',
    referenceId: 'EVA-QRIS-20261125-004',
    providerReference: 'midtrans-ord-990195',
    actorLabel: 'Bagus Saputra (U-312)',
    amountIdr: 25000,
    feeIdr: null,
    netAmountIdr: null,
    walletDebitIdr: null,
    currency: 'IDR',
    status: 'pending',
    reconciliationStatus: 'pending',
    createdAt: '2026-11-25T11:40:00.000Z',
    completedAt: null,
    bankAccountMasked: null,
    events: [
      {
        status: 'pending',
        occurredAt: '2026-11-25T11:40:00.000Z',
        source: 'backend',
        message: 'Menunggu pembayaran QRIS oleh pengguna',
      },
    ],
  },
  {
    id: 'fin-qris-004',
    direction: 'in',
    source: 'qris_topup',
    referenceId: 'EVA-QRIS-20261120-008',
    providerReference: 'midtrans-ord-989870',
    actorLabel: 'Sinta Wijaya (U-087)',
    amountIdr: 150000,
    feeIdr: 1050,
    netAmountIdr: 148950,
    walletDebitIdr: null,
    currency: 'IDR',
    status: 'paid',
    reconciliationStatus: 'matched',
    createdAt: '2026-11-20T05:00:00.000Z',
    completedAt: '2026-11-20T05:01:22.000Z',
    bankAccountMasked: null,
    events: [
      {
        status: 'pending',
        occurredAt: '2026-11-20T05:00:00.000Z',
        source: 'backend',
        message: 'Tagihan QRIS dibuat untuk Paket Hemat 170 Koin',
      },
      {
        status: 'paid',
        occurredAt: '2026-11-20T05:01:22.000Z',
        source: 'midtrans',
        message: 'Pembayaran QRIS terkonfirmasi',
      },
      {
        status: 'matched',
        occurredAt: '2026-11-20T05:05:00.000Z',
        source: 'reconciler',
        message: 'Status transaksi cocok dengan laporan penyelesaian',
      },
    ],
  },
  {
    id: 'fin-qris-005',
    direction: 'in',
    source: 'qris_topup',
    referenceId: 'EVA-QRIS-20261118-011',
    providerReference: 'midtrans-ord-989512',
    actorLabel: 'Nadya Putri (U-155)',
    amountIdr: 50000,
    feeIdr: null,
    netAmountIdr: null,
    walletDebitIdr: null,
    currency: 'IDR',
    status: 'expired',
    reconciliationStatus: 'unknown',
    createdAt: '2026-11-18T08:25:00.000Z',
    completedAt: null,
    bankAccountMasked: null,
    events: [
      {
        status: 'pending',
        occurredAt: '2026-11-18T08:25:00.000Z',
        source: 'backend',
        message: 'Tagihan QRIS diterbitkan',
      },
      {
        status: 'expired',
        occurredAt: '2026-11-18T08:40:00.000Z',
        source: 'midtrans',
        message: 'Batas waktu pembayaran QRIS berakhir tanpa settlement',
      },
    ],
  },
  {
    id: 'fin-out-001',
    direction: 'out',
    source: 'counselor_payout',
    referenceId: 'EVA-PAYOUT-20261124-002',
    providerReference: 'iris-ref-552190',
    actorLabel: 'dr. Sarah Amelia, M.Psi.',
    amountIdr: 450000,
    feeIdr: 5000,
    netAmountIdr: 445000,
    walletDebitIdr: 450000,
    currency: 'IDR',
    status: 'completed',
    reconciliationStatus: 'matched',
    createdAt: '2026-11-24T04:00:00.000Z',
    completedAt: '2026-11-24T04:12:30.000Z',
    bankAccountMasked: 'BCA **** 4821',
    events: [
      {
        status: 'requested',
        occurredAt: '2026-11-24T04:00:00.000Z',
        source: 'backend',
        message: 'Pengajuan pencairan honorarium mengunci 450 Koin',
      },
      {
        status: 'waiting_approval',
        occurredAt: '2026-11-24T04:01:05.000Z',
        source: 'iris',
        message: 'Antrean approval dicatat di Iris Dashboard',
      },
      {
        status: 'completed',
        occurredAt: '2026-11-24T04:12:30.000Z',
        source: 'iris',
        message: 'Dana transfer berhasil diterima rekening tujuan',
      },
    ],
  },
  {
    id: 'fin-out-002',
    direction: 'out',
    source: 'counselor_payout',
    referenceId: 'EVA-PAYOUT-20261125-003',
    providerReference: 'iris-ref-552214',
    actorLabel: 'Maya Kusuma, M.Psi.',
    amountIdr: 300000,
    feeIdr: 5000,
    netAmountIdr: 295000,
    walletDebitIdr: 300000,
    currency: 'IDR',
    status: 'waiting_approval',
    reconciliationStatus: 'pending',
    createdAt: '2026-11-25T03:30:00.000Z',
    completedAt: null,
    bankAccountMasked: 'Mandiri **** 3319',
    events: [
      {
        status: 'requested',
        occurredAt: '2026-11-25T03:30:00.000Z',
        source: 'backend',
        message: 'Permintaan pencairan honorarium dibuat dari aplikasi Counselor',
      },
      {
        status: 'waiting_approval',
        occurredAt: '2026-11-25T03:30:40.000Z',
        source: 'iris',
        message: 'Menunggu approval operasional di Iris Dashboard',
      },
    ],
  },
  {
    id: 'fin-out-003',
    direction: 'out',
    source: 'payment_refund',
    referenceId: 'EVA-REFUND-20261122-001',
    providerReference: 'midtrans-ref-77102',
    actorLabel: 'Tania Lestari (U-092)',
    amountIdr: 50000,
    feeIdr: 0,
    netAmountIdr: 50000,
    walletDebitIdr: 50000,
    currency: 'IDR',
    status: 'completed',
    reconciliationStatus: 'matched',
    createdAt: '2026-11-22T09:15:00.000Z',
    completedAt: '2026-11-22T09:18:05.000Z',
    bankAccountMasked: null,
    events: [
      {
        status: 'processing',
        occurredAt: '2026-11-22T09:15:00.000Z',
        source: 'backend',
        message: 'Permintaan refund pembayaran QRIS ganda diteruskan',
      },
      {
        status: 'completed',
        occurredAt: '2026-11-22T09:18:05.000Z',
        source: 'midtrans',
        message: 'Refund selesai diproses provider',
      },
    ],
  },
  {
    id: 'fin-out-004',
    direction: 'out',
    source: 'payout_reversal',
    referenceId: 'EVA-REV-20261119-001',
    providerReference: 'iris-rev-551801',
    actorLabel: 'Bima Wijaya, M.Psi.',
    amountIdr: 200000,
    feeIdr: null,
    netAmountIdr: null,
    walletDebitIdr: 200000,
    currency: 'IDR',
    status: 'reversed',
    reconciliationStatus: 'review_required',
    createdAt: '2026-11-19T06:45:00.000Z',
    completedAt: '2026-11-19T07:10:00.000Z',
    bankAccountMasked: 'BRI **** 9024',
    events: [
      {
        status: 'processing',
        occurredAt: '2026-11-19T06:45:00.000Z',
        source: 'iris',
        message: 'Transfer payout dikirim ke bank penerima',
      },
      {
        status: 'reversed',
        occurredAt: '2026-11-19T07:10:00.000Z',
        source: 'iris',
        message: 'Transfer dibalikkan oleh bank penerima, saldo honorarium dipulihkan',
      },
      {
        status: 'review_required',
        occurredAt: '2026-11-19T07:12:00.000Z',
        source: 'reconciler',
        message: 'Membutuhkan verifikasi ulang rekening tujuan sebelum pencairan ulang',
      },
    ],
  },
]

function isInsideHalfOpenRange(createdAtIso: string, fromIso: string, toIso: string): boolean {
  const createdMs = Date.parse(createdAtIso)
  const fromMs = Date.parse(fromIso)
  const toMs = Date.parse(toIso)
  if (Number.isNaN(createdMs) || Number.isNaN(fromMs) || Number.isNaN(toMs)) {
    return true
  }
  return createdMs >= fromMs && createdMs < toMs
}

export function queryMockFinanceSummary(params: {
  from: string
  to: string
}): FinanceSummary {
  const inPeriod = MOCK_FINANCE_TRANSACTIONS.filter((tx) =>
    isInsideHalfOpenRange(tx.createdAt, params.from, params.to),
  )

  let moneyInPaidIdr = 0
  let moneyInPendingIdr = 0
  let moneyOutCompletedIdr = 0
  let moneyOutPendingIdr = 0
  let refundCompletedIdr = 0
  let knownFeesSum = 0
  let hasKnownFee = false

  for (const tx of inPeriod) {
    const amount = tx.amountIdr ?? 0
    if (tx.feeIdr !== null) {
      knownFeesSum += tx.feeIdr
      hasKnownFee = true
    }

    if (tx.direction === 'in') {
      if (tx.status === 'paid' || tx.status === 'completed') {
        moneyInPaidIdr += amount
      } else if (tx.status === 'pending') {
        moneyInPendingIdr += amount
      }
    } else if (tx.source === 'payment_refund') {
      if (tx.status === 'completed' || tx.status === 'paid') {
        refundCompletedIdr += amount
      }
    } else if (tx.source === 'counselor_payout') {
      if (tx.status === 'completed') {
        moneyOutCompletedIdr += amount
      } else if (
        tx.status === 'requested' ||
        tx.status === 'waiting_approval' ||
        tx.status === 'processing'
      ) {
        moneyOutPendingIdr += amount
      }
    }
  }

  const unreconciledCount = MOCK_FINANCE_TRANSACTIONS.filter(
    (tx) =>
      tx.reconciliationStatus === 'mismatch' ||
      tx.reconciliationStatus === 'review_required',
  ).length

  return {
    currency: 'IDR',
    from: params.from,
    to: params.to,
    moneyInPaidIdr,
    moneyInPendingIdr,
    moneyOutCompletedIdr,
    moneyOutPendingIdr,
    refundCompletedIdr,
    providerFeesKnownIdr: hasKnownFee ? knownFeesSum : null,
    commissionEarnedIdr: Math.round(moneyOutCompletedIdr * 0.15),
    clientCreditLiabilityIdr: 1500000,
    counselorPayableIdr: 750000,
    unreconciledCount,
    providerPayoutAvailableIdr: 2000000,
    providerBalanceAsOf: '2026-11-25T11:45:00.000Z',
  }
}

export function queryMockFinanceTransactions(
  query: FinanceTransactionsQuery,
): PaginatedFinanceTransactions {
  const searchTerm = query.q?.trim().toLowerCase() ?? ''
  const statusFilter = query.status?.trim().toLowerCase() ?? ''

  const filtered = MOCK_FINANCE_TRANSACTIONS.filter((tx) => {
    if (!isInsideHalfOpenRange(tx.createdAt, query.from, query.to)) return false
    if (query.direction && tx.direction !== query.direction) return false
    if (query.source && tx.source !== query.source) return false
    if (statusFilter && tx.status.toLowerCase() !== statusFilter) return false
    if (
      searchTerm &&
      !tx.referenceId.toLowerCase().includes(searchTerm) &&
      !tx.actorLabel.toLowerCase().includes(searchTerm) &&
      !(tx.providerReference || '').toLowerCase().includes(searchTerm)
    ) {
      return false
    }
    return true
  }).sort((a, b) => {
    const tDiff = Date.parse(b.createdAt) - Date.parse(a.createdAt)
    return tDiff !== 0 ? tDiff : b.id.localeCompare(a.id)
  })

  const pageSize = Math.min(100, Math.max(1, query.pageSize))
  const page = Math.max(1, query.page)
  const start = (page - 1) * pageSize

  return {
    items: filtered.slice(start, start + pageSize),
    page,
    pageSize,
    total: filtered.length,
  }
}

export function queryMockFinanceTransactionDetail(
  transactionId: string,
): FinanceTransactionDetail {
  const found = MOCK_FINANCE_TRANSACTIONS.find((tx) => tx.id === transactionId)
  if (!found) {
    throw new Error('Detail transaksi keuangan tidak ditemukan di mode mock.')
  }
  return found
}
