import {
  CheckCircle2,
  Clock,
  Coins,
  Plus,
  RotateCcw,
  Search,
  Sparkles,
  Wallet,
  XCircle,
} from 'lucide-react'
import { useMemo, useState, type FormEvent } from 'react'
import { cn } from '@/lib/cn'
import {
  reviewCoinTransaction,
  toggleCoinPackageActive,
  updateCoinEconomyConfig,
  upsertCoinPackage,
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

  // Economy config state
  const [basePriceInput, setBasePriceInput] = useState(
    String(db.coinEconomyConfig.basePricePerCoinIdr),
  )
  const [freeTrialInput, setFreeTrialInput] = useState(
    String(db.coinEconomyConfig.freeTrialCoinsNewUser),
  )

  // New package modal/form state
  const [showAddPackage, setShowAddPackage] = useState(false)
  const [pkgCode, setPkgCode] = useState('')
  const [pkgName, setPkgName] = useState('')
  const [pkgCoins, setPkgCoins] = useState('50')
  const [pkgBonus, setPkgBonus] = useState('10')
  const [pkgPrice, setPkgPrice] = useState('45000')
  const [pkgDesc, setPkgDesc] = useState('')

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

  const handleSaveEconomyConfig = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    const basePrice = Math.max(100, Number(basePriceInput) || 1000)
    const freeTrial = Math.max(0, Number(freeTrialInput) || 0)

    updateCoinEconomyConfig({
      basePricePerCoinIdr: basePrice,
      freeTrialCoinsNewUser: freeTrial,
    })
    onFeedback(
      `Konfigurasi nilai koin berhasil diperbarui: Rp${basePrice.toLocaleString('id-ID')}/Koin (1 Koin = 1 Menit Suara).`,
    )
  }

  const handleAddPackage = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    if (!pkgCode.trim() || !pkgName.trim()) return

    const coins = Math.max(1, Number(pkgCoins) || 15)
    const bonusCoins = Math.max(0, Number(pkgBonus) || 0)
    const priceIdr = Math.max(1000, Number(pkgPrice) || coins * 1000)

    const created = upsertCoinPackage({
      code: pkgCode.trim().toUpperCase(),
      name: pkgName.trim(),
      coins,
      bonusCoins,
      priceIdr,
      description:
        pkgDesc.trim() ||
        `Total ${coins + bonusCoins} menit sesi berbicara bersama EVA (${coins} koin pokok + ${bonusCoins} bonus).`,
      isActive: true,
    })

    setPkgCode('')
    setPkgName('')
    setPkgDesc('')
    setShowAddPackage(false)
    onFeedback(`Paket koin "${created.name}" berhasil ditambahkan ke katalog top-up.`)
  }

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

      {/* 2. Base Rate Configuration & Bundling Packages */}
      <div className="grid grid-cols-1 gap-5 lg:grid-cols-12">
        {/* Left: Economy Config Form */}
        <form
          onSubmit={handleSaveEconomyConfig}
          className="rounded-[12px] border border-[#E2E8F0] bg-white p-5 lg:col-span-4"
        >
          <h2 className="text-sm font-bold text-ink">
            Pengaturan Kurs Dasar &amp; Kuota Trial
          </h2>
          <p className="mt-0.5 text-xs text-ink-muted">
            Atur nilai konversi dasar untuk 1 Koin (1 menit sesi suara AI EVA) dan bonus registrasi awal.
          </p>

          <div className="mt-4 space-y-3.5 text-xs">
            <div>
              <label className="block font-semibold text-ink">
                Harga Dasar per 1 Koin (1 Menit Suara) - Rp
              </label>
              <input
                type="number"
                min={100}
                step={100}
                value={basePriceInput}
                onChange={(e) => setBasePriceInput(e.target.value)}
                className="mt-1 h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 font-semibold text-ink focus:border-primary focus:outline-none"
              />
              <p className="mt-1 text-[11px] text-ink-muted">
                Acuan harga normal sebelum diskon atau bonus bundling.
              </p>
            </div>

            <div>
              <label className="block font-semibold text-ink">
                Bonus Koin Gratis Pengguna Baru (Free Trial)
              </label>
              <input
                type="number"
                min={0}
                max={120}
                value={freeTrialInput}
                onChange={(e) => setFreeTrialInput(e.target.value)}
                className="mt-1 h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 font-semibold text-ink focus:border-primary focus:outline-none"
              />
              <p className="mt-1 text-[11px] text-ink-muted">
                Otomatis diberikan saat pengguna pertama kali membuat akun di aplikasi mobile.
              </p>
            </div>

            <button
              type="submit"
              className="inline-flex h-9 w-full cursor-pointer items-center justify-center rounded-[8px] bg-primary px-4 text-xs font-semibold text-white transition-colors hover:bg-primary-hover"
            >
              Simpan Pengaturan Kurs Koin
            </button>
          </div>
        </form>

        {/* Right: Coin Bundling Packages */}
        <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-5 lg:col-span-8">
          <div className="flex flex-wrap items-center justify-between gap-2 border-b border-[#E2E8F0] pb-3.5">
            <div>
              <h2 className="text-sm font-bold text-ink">
                Katalog Paket Bundling Top-Up Koin
              </h2>
              <p className="text-xs text-ink-muted">
                Paket pembelian koin yang tampil pada menu Top-Up di aplikasi mobile EVA.
              </p>
            </div>
            <button
              type="button"
              onClick={() => setShowAddPackage((prev) => !prev)}
              className="inline-flex h-8 cursor-pointer items-center gap-1.5 rounded-[8px] border border-[#CBD5E1] bg-[#F8FAFC] px-3 text-xs font-semibold text-ink transition-colors hover:border-primary hover:text-primary"
            >
              <Plus className="size-3.5" />
              <span>{showAddPackage ? 'Tutup Form' : 'Tambah Paket'}</span>
            </button>
          </div>

          {showAddPackage && (
            <form
              onSubmit={handleAddPackage}
              className="mt-3.5 rounded-[10px] border border-[#CBD5E1] bg-[#F8FAFC] p-4 text-xs"
            >
              <p className="font-bold text-ink">Tambah Paket Bundling Koin Baru</p>
              <div className="mt-3 grid grid-cols-1 gap-3 sm:grid-cols-3">
                <div>
                  <label className="block font-semibold text-ink">Kode Paket *</label>
                  <input
                    type="text"
                    required
                    value={pkgCode}
                    onChange={(e) => setPkgCode(e.target.value.toUpperCase())}
                    placeholder="COIN-60"
                    className="mt-1 h-8 w-full rounded-[6px] border border-[#CBD5E1] bg-white px-2.5 font-mono uppercase text-ink"
                  />
                </div>
                <div className="sm:col-span-2">
                  <label className="block font-semibold text-ink">Nama Paket *</label>
                  <input
                    type="text"
                    required
                    value={pkgName}
                    onChange={(e) => setPkgName(e.target.value)}
                    placeholder="Paket Curhat Mingguan"
                    className="mt-1 h-8 w-full rounded-[6px] border border-[#CBD5E1] bg-white px-2.5 text-ink"
                  />
                </div>
                <div>
                  <label className="block font-semibold text-ink">Koin Pokok (Menit)</label>
                  <input
                    type="number"
                    min={1}
                    value={pkgCoins}
                    onChange={(e) => setPkgCoins(e.target.value)}
                    className="mt-1 h-8 w-full rounded-[6px] border border-[#CBD5E1] bg-white px-2.5 text-ink"
                  />
                </div>
                <div>
                  <label className="block font-semibold text-ink">Bonus Koin</label>
                  <input
                    type="number"
                    min={0}
                    value={pkgBonus}
                    onChange={(e) => setPkgBonus(e.target.value)}
                    className="mt-1 h-8 w-full rounded-[6px] border border-[#CBD5E1] bg-white px-2.5 text-ink"
                  />
                </div>
                <div>
                  <label className="block font-semibold text-ink">Harga Paket (Rp)</label>
                  <input
                    type="number"
                    min={1000}
                    step={500}
                    value={pkgPrice}
                    onChange={(e) => setPkgPrice(e.target.value)}
                    className="mt-1 h-8 w-full rounded-[6px] border border-[#CBD5E1] bg-white px-2.5 text-ink"
                  />
                </div>
                <div className="sm:col-span-3">
                  <label className="block font-semibold text-ink">Deskripsi Singkat</label>
                  <input
                    type="text"
                    value={pkgDesc}
                    onChange={(e) => setPkgDesc(e.target.value)}
                    placeholder="Keterangan kuota menit sesi suara dan penghematan..."
                    className="mt-1 h-8 w-full rounded-[6px] border border-[#CBD5E1] bg-white px-2.5 text-ink"
                  />
                </div>
              </div>
              <div className="mt-3 flex justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setShowAddPackage(false)}
                  className="h-8 cursor-pointer rounded-[6px] border border-[#CBD5E1] bg-white px-3 font-semibold text-ink-soft"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  className="h-8 cursor-pointer rounded-[6px] bg-primary px-3.5 font-semibold text-white hover:bg-primary-hover"
                >
                  Simpan Paket
                </button>
              </div>
            </form>
          )}

          <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2">
            {db.coinPackages.map((pkg) => {
              const totalCoins = pkg.coins + pkg.bonusCoins
              const effectivePerCoin = Math.round(pkg.priceIdr / totalCoins)

              return (
                <div
                  key={pkg.id}
                  className={cn(
                    'flex flex-col justify-between rounded-[10px] border p-3.5 transition-all',
                    pkg.isActive
                      ? 'border-[#E2E8F0] bg-[#F8FAFC]/60'
                      : 'border-[#E2E8F0] bg-slate-50 opacity-60',
                  )}
                >
                  <div>
                    <div className="flex items-start justify-between gap-2">
                      <div>
                        <div className="flex items-center gap-1.5">
                          <span className="font-mono text-[10px] font-bold text-primary">
                            {pkg.code}
                          </span>
                          {pkg.isPopular && (
                            <span className="rounded-[4px] bg-amber-100 px-1.5 py-0.5 text-[10px] font-bold text-amber-800">
                              Populer
                            </span>
                          )}
                        </div>
                        <h3 className="mt-0.5 text-xs font-bold text-ink">{pkg.name}</h3>
                      </div>

                      <span className="text-sm font-extrabold text-primary">
                        Rp{pkg.priceIdr.toLocaleString('id-ID')}
                      </span>
                    </div>

                    <div className="mt-2 flex flex-wrap items-center gap-1.5 text-[11px]">
                      <span className="rounded-[5px] bg-white px-2 py-0.5 font-semibold text-ink shadow-2xs">
                        {pkg.coins} Koin ({pkg.coins} mnt)
                      </span>
                      {pkg.bonusCoins > 0 && (
                        <span className="rounded-[5px] bg-emerald-50 px-2 py-0.5 font-bold text-emerald-700">
                          +{pkg.bonusCoins} Bonus Koin
                        </span>
                      )}
                      <span className="text-ink-muted">
                        · ~Rp{effectivePerCoin.toLocaleString('id-ID')}/mnt
                      </span>
                    </div>

                    <p className="mt-2 text-[11px] leading-snug text-ink-muted">
                      {pkg.description}
                    </p>
                  </div>

                  <div className="mt-3 flex items-center justify-between border-t border-[#E2E8F0] pt-2.5 text-[11px]">
                    <span
                      className={cn(
                        'font-semibold',
                        pkg.isActive ? 'text-emerald-700' : 'text-ink-muted',
                      )}
                    >
                      {pkg.isActive ? 'Tampil di Aplikasi' : 'Nonaktif'}
                    </span>
                    <button
                      type="button"
                      onClick={() => {
                        toggleCoinPackageActive(pkg.id)
                        onFeedback(
                          `Status paket "${pkg.name}" berhasil diperbarui.`,
                        )
                      }}
                      className="cursor-pointer font-semibold text-primary hover:underline"
                    >
                      {pkg.isActive ? 'Nonaktifkan' : 'Aktifkan'}
                    </button>
                  </div>
                </div>
              )
            })}
          </div>
        </div>
      </div>

      {/* 3. Top-Up Transactions History Table */}
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

