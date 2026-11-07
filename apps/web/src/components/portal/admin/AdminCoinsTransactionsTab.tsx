import {
  CheckCircle2,
  Clock,
  Coins,
  RotateCcw,
  Search,
  Sparkles,
  Wallet,
  XCircle,
} from 'lucide-react'
import { useMemo, useState } from 'react'
import { cn } from '@/lib/cn'
import {
  reviewCoinTransaction,
  type CoinTransactionStatus,
  type PortalDatabase,
} from '@/lib/portalStore'

interface AdminCoinsTransactionsTabProps {
  db: PortalDatabase
  onFeedback: (message: string) => void
}

type TrxFilter = 'all' | 'pending' | 'completed' | 'refunded_failed'

export function AdminCoinsTransactionsTab({
  db,
  onFeedback,
}: AdminCoinsTransactionsTabProps) {
  const [trxFilter, setTrxFilter] = useState<TrxFilter>('all')
  const [trxSearch, setTrxSearch] = useState('')

  // KPI calculations
  const kpiStats = useMemo(() => {
    const completedTrx = db.coinTransactions.filter(
      (t) => t.status === 'completed' && t.amountIdr > 0,
    )
    const totalRevenueIdr = completedTrx.reduce((sum, t) => sum + t.amountIdr, 0)
    const totalCoinsSold = completedTrx.reduce((sum, t) => sum + t.coinsGranted, 0)
    const pendingCount = db.coinTransactions.filter((t) => t.status === 'pending').length
    const circulatingCoins = db.generalUsers.reduce(
      (sum, u) => sum + (u.coinBalance ?? 0),
      0,
    )
    const totalMinutesUsed = db.generalUsers.reduce(
      (sum, u) => sum + (u.totalVoiceMinutesUsed ?? 0),
      0,
    )

    return {
      totalRevenueIdr,
      totalCoinsSold,
      pendingCount,
      circulatingCoins,
      totalMinutesUsed,
    }
  }, [db.coinTransactions, db.generalUsers])

  const filteredTransactions = useMemo(() => {
    const q = trxSearch.trim().toLowerCase()
    return db.coinTransactions.filter((t) => {
      if (trxFilter === 'pending' && t.status !== 'pending') return false
      if (trxFilter === 'completed' && t.status !== 'completed') return false
      if (
        trxFilter === 'refunded_failed' &&
        t.status !== 'refunded' &&
        t.status !== 'failed'
      ) {
        return false
      }

      if (!q) return true
      return (
        t.invoiceCode.toLowerCase().includes(q) ||
        t.userDisplayName.toLowerCase().includes(q) ||
        t.userCode.toLowerCase().includes(q) ||
        t.packageName.toLowerCase().includes(q) ||
        t.paymentMethod.toLowerCase().includes(q)
      )
    })
  }, [db.coinTransactions, trxFilter, trxSearch])

  const handleUpdateTransactionStatus = (
    trxId: string,
    invoiceCode: string,
    nextStatus: CoinTransactionStatus,
  ) => {
    const defaultNote =
      nextStatus === 'completed'
        ? 'Dikonfirmasi lunas oleh Admin. Saldo koin pengguna otomatis ditambahkan.'
        : nextStatus === 'refunded'
          ? 'Dana dikembalikan (Refund) oleh Admin dan saldo koin telah disesuaikan.'
          : 'Transaksi dibatalkan oleh Admin.'

    reviewCoinTransaction(trxId, nextStatus, defaultNote)
    onFeedback(`Status transaksi "${invoiceCode}" diperbarui menjadi ${nextStatus.toUpperCase()}.`)
  }

  return (
    <div className="mt-5 space-y-5">
      {/* 1. KPI Summary Cards */}
      <div className="grid grid-cols-1 gap-3.5 sm:grid-cols-2 xl:grid-cols-4">
        <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-4">
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-bold tracking-wider text-ink-muted uppercase">
              Pendapatan Top-Up Koin
            </span>
            <span className="flex size-8 items-center justify-center rounded-[8px] bg-emerald-50 text-emerald-700">
              <Wallet className="size-4" />
            </span>
          </div>
          <p className="mt-2 text-xl font-bold text-ink">
            Rp{kpiStats.totalRevenueIdr.toLocaleString('id-ID')}
          </p>
          <p className="mt-0.5 text-xs text-ink-muted">
            {kpiStats.totalCoinsSold.toLocaleString('id-ID')} koin terjual (lunas)
          </p>
        </div>

        <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-4">
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-bold tracking-wider text-ink-muted uppercase">
              Koin Beredar &amp; Terpakai
            </span>
            <span className="flex size-8 items-center justify-center rounded-[8px] bg-[#EEF0FF] text-primary">
              <Coins className="size-4" />
            </span>
          </div>
          <p className="mt-2 text-xl font-bold text-ink">
            {kpiStats.circulatingCoins.toLocaleString('id-ID')} Koin Aktif
          </p>
          <p className="mt-0.5 text-xs text-ink-muted">
            {kpiStats.totalMinutesUsed.toLocaleString('id-ID')} menit suara telah digunakan
          </p>
        </div>

        <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-4">
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-bold tracking-wider text-ink-muted uppercase">
              Antrean Konfirmasi Top-Up
            </span>
            <span className="flex size-8 items-center justify-center rounded-[8px] bg-amber-50 text-amber-700">
              <Clock className="size-4" />
            </span>
          </div>
          <p className="mt-2 text-xl font-bold text-ink">
            {kpiStats.pendingCount} Transaksi
          </p>
          <p className="mt-0.5 text-xs text-ink-muted">
            Menunggu verifikasi pembayaran masuk
          </p>
        </div>

        <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-4">
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-bold tracking-wider text-ink-muted uppercase">
              Kurs Dasar EVA Coin
            </span>
            <span className="flex size-8 items-center justify-center rounded-[8px] bg-indigo-50 text-indigo-700">
              <Sparkles className="size-4" />
            </span>
          </div>
          <p className="mt-2 text-xl font-bold text-ink">
            Rp{db.coinEconomyConfig.basePricePerCoinIdr.toLocaleString('id-ID')} / Koin
          </p>
          <p className="mt-0.5 text-xs text-ink-muted">
            1 Koin = 1 Menit bicara · Trial baru: {db.coinEconomyConfig.freeTrialCoinsNewUser} Koin
          </p>
        </div>
      </div>

      {/* 2. Top-Up Transactions History Table (Primary Focus) */}
      <div className="rounded-[12px] border border-[#E2E8F0] bg-white">
        <div className="flex flex-col justify-between gap-3 border-b border-[#E2E8F0] p-4 sm:flex-row sm:items-center">
          <div>
            <h2 className="text-sm font-bold text-ink">
              Riwayat Transaksi Top-Up Koin Pengguna
            </h2>
            <p className="text-xs text-ink-muted">
              Verifikasi pembayaran masuk dan pantau distribusi koin menit bicara ke akun pengguna.
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <div className="inline-flex rounded-[8px] bg-[#F1F5F9] p-1 text-xs">
              {(
                [
                  { id: 'all', label: `Semua (${db.coinTransactions.length})` },
                  {
                    id: 'pending',
                    label: `Menunggu (${db.coinTransactions.filter((t) => t.status === 'pending').length})`,
                  },
                  {
                    id: 'completed',
                    label: `Berhasil (${db.coinTransactions.filter((t) => t.status === 'completed').length})`,
                  },
                  {
                    id: 'refunded_failed',
                    label: `Refund/Batal (${db.coinTransactions.filter((t) => t.status === 'refunded' || t.status === 'failed').length})`,
                  },
                ] as const
              ).map((tab) => (
                <button
                  key={tab.id}
                  type="button"
                  onClick={() => setTrxFilter(tab.id)}
                  className={cn(
                    'cursor-pointer rounded-[6px] px-2.5 py-1 text-[11px] font-semibold transition-colors',
                    trxFilter === tab.id
                      ? 'bg-white text-ink shadow-2xs'
                      : 'text-ink-muted hover:text-ink',
                  )}
                >
                  {tab.label}
                </button>
              ))}
            </div>

            <div className="relative w-full sm:w-64">
              <Search className="pointer-events-none absolute top-1/2 left-3 size-3.5 -translate-y-1/2 text-ink-muted" />
              <input
                type="search"
                value={trxSearch}
                onChange={(e) => setTrxSearch(e.target.value)}
                placeholder="Cari invoice, pengguna, metode..."
                className="h-8 w-full rounded-[8px] border border-[#CBD5E1] bg-[#F8FAFC] pr-3 pl-8 text-xs text-ink focus:border-primary focus:bg-white focus:outline-none"
              />
            </div>
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full border-collapse text-left">
            <thead>
              <tr className="border-b border-[#E2E8F0] bg-[#F8FAFC] text-[11px] font-bold tracking-wider text-ink-muted uppercase">
                <th className="px-4 py-3">Invoice &amp; Waktu</th>
                <th className="px-4 py-3">Pengguna</th>
                <th className="px-4 py-3">Paket &amp; Kuota Koin</th>
                <th className="px-4 py-3">Nominal &amp; Metode</th>
                <th className="px-4 py-3">Status</th>
                <th className="px-4 py-3 text-right">Tindakan Admin</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#E2E8F0] text-xs">
              {filteredTransactions.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-4 py-8 text-center text-ink-muted">
                    Tidak ada transaksi top-up koin yang sesuai dengan filter pencarian.
                  </td>
                </tr>
              ) : (
                filteredTransactions.map((trx) => (
                  <tr key={trx.id} className="hover:bg-[#F8FAFC]">
                    <td className="px-4 py-3.5">
                      <p className="font-mono font-bold text-ink">{trx.invoiceCode}</p>
                      <p className="text-[11px] text-ink-muted">{trx.createdAt}</p>
                    </td>
                    <td className="px-4 py-3.5">
                      <p className="font-semibold text-ink">{trx.userDisplayName}</p>
                      <p className="font-mono text-[11px] text-ink-muted">{trx.userCode}</p>
                    </td>
                    <td className="px-4 py-3.5">
                      <p className="font-semibold text-ink">{trx.packageName}</p>
                      <span className="mt-0.5 inline-flex items-center gap-1 rounded-[5px] bg-[#EEF0FF] px-2 py-0.5 text-[11px] font-bold text-primary">
                        <Coins className="size-3" /> +{trx.coinsGranted} Koin ({trx.coinsGranted} menit)
                      </span>
                    </td>
                    <td className="px-4 py-3.5">
                      <p className="font-bold text-ink">
                        {trx.amountIdr > 0
                          ? `Rp${trx.amountIdr.toLocaleString('id-ID')}`
                          : 'Gratis (Grant Admin)'}
                      </p>
                      <p className="text-[11px] text-ink-muted">Via {trx.paymentMethod}</p>
                    </td>
                    <td className="px-4 py-3.5">
                      <span
                        className={cn(
                          'inline-flex items-center gap-1 rounded-[6px] px-2 py-0.5 text-[11px] font-semibold',
                          trx.status === 'completed'
                            ? 'bg-emerald-50 text-emerald-800'
                            : trx.status === 'pending'
                              ? 'bg-amber-50 text-amber-800'
                              : 'bg-slate-100 text-ink-muted',
                        )}
                      >
                        {trx.status === 'completed' && <CheckCircle2 className="size-3" />}
                        {trx.status === 'pending' && <Clock className="size-3" />}
                        {(trx.status === 'refunded' || trx.status === 'failed') && (
                          <XCircle className="size-3" />
                        )}
                        {trx.status === 'completed'
                          ? 'Berhasil'
                          : trx.status === 'pending'
                            ? 'Menunggu Pembayaran'
                            : trx.status === 'refunded'
                              ? 'Refund'
                              : 'Dibatalkan'}
                      </span>
                      {trx.adminNotes && (
                        <p className="mt-1 max-w-xs text-[11px] text-ink-muted">
                          {trx.adminNotes}
                        </p>
                      )}
                    </td>
                    <td className="px-4 py-3.5 text-right">
                      {trx.status === 'pending' ? (
                        <div className="inline-flex items-center gap-1.5">
                          <button
                            type="button"
                            onClick={() =>
                              handleUpdateTransactionStatus(
                                trx.id,
                                trx.invoiceCode,
                                'completed',
                              )
                            }
                            className="inline-flex h-7 cursor-pointer items-center gap-1 rounded-[6px] bg-emerald-600 px-2.5 text-[11px] font-semibold text-white hover:bg-emerald-700"
                          >
                            <CheckCircle2 className="size-3" />
                            <span>Konfirmasi Lunas</span>
                          </button>
                          <button
                            type="button"
                            onClick={() =>
                              handleUpdateTransactionStatus(trx.id, trx.invoiceCode, 'failed')
                            }
                            className="inline-flex h-7 cursor-pointer items-center gap-1 rounded-[6px] border border-[#CBD5E1] bg-white px-2 text-[11px] font-semibold text-ink-soft hover:bg-slate-50"
                          >
                            Batalkan
                          </button>
                        </div>
                      ) : trx.status === 'completed' && trx.amountIdr > 0 ? (
                        <button
                          type="button"
                          onClick={() =>
                            handleUpdateTransactionStatus(trx.id, trx.invoiceCode, 'refunded')
                          }
                          className="inline-flex h-7 cursor-pointer items-center gap-1 rounded-[6px] border border-[#CBD5E1] bg-white px-2.5 text-[11px] font-semibold text-ink-soft hover:border-amber-400 hover:text-ink"
                        >
                          <RotateCcw className="size-3" />
                          <span>Tandai Refund</span>
                        </button>
                      ) : (
                        <span className="text-[11px] text-ink-muted">Selesai</span>
                      )}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
