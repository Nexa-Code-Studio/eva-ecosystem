import { AlertCircle, Coins, Loader2, Pencil, Plus, Sparkles, Star, Trash2 } from 'lucide-react'
import { useRef, useState, type FormEvent } from 'react'
import { TablePagination } from '@/components/portal/TablePagination'
import { useUrlPagination } from '@/hooks/useUrlPagination'
import { cn } from '@/lib/cn'
import {
  deleteCoinPackage,
  toggleCoinPackageActive,
  updateCoinEconomyConfig,
  upsertCoinPackage,
  type CoinEconomyConfig,
  type CoinPackage,
  type PortalDatabase,
} from '@/lib/portalStore'

interface AdminCoinPackagesConfigTabProps {
  db: PortalDatabase
  onFeedback: (message: string) => void
}

interface CoinPackageFormProps {
  initialPackage: CoinPackage | null
  basePricePerCoinIdr: number
  existingPackages: CoinPackage[]
  onSave: (saved: CoinPackage, isEdit: boolean) => void
  onCancel: () => void
}

function CoinPackageForm({
  initialPackage,
  basePricePerCoinIdr,
  existingPackages,
  onSave,
  onCancel,
}: CoinPackageFormProps) {
  const isEdit = initialPackage !== null
  const [pkgCode, setPkgCode] = useState(initialPackage?.code ?? '')
  const [pkgName, setPkgName] = useState(initialPackage?.name ?? '')
  const [pkgCoins, setPkgCoins] = useState(String(initialPackage?.coins ?? 50))
  const [pkgBonus, setPkgBonus] = useState(String(initialPackage?.bonusCoins ?? 10))
  const [pkgPrice, setPkgPrice] = useState(String(initialPackage?.priceIdr ?? 45000))
  const [pkgDesc, setPkgDesc] = useState(initialPackage?.description ?? '')
  const [pkgPopular, setPkgPopular] = useState(Boolean(initialPackage?.isPopular))
  const [formError, setFormError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)

  const coinsNum = Math.max(0, Math.round(Number(pkgCoins) || 0))
  const bonusNum = Math.max(0, Math.round(Number(pkgBonus) || 0))
  const totalCoins = coinsNum + bonusNum
  const priceNum = Math.max(0, Math.round(Number(pkgPrice) || 0))
  const effectivePerCoin = totalCoins > 0 ? Math.round(priceNum / totalCoins) : 0
  const normalTotalIdr = totalCoins * Math.max(1, basePricePerCoinIdr)
  const savingsPct =
    normalTotalIdr > 0 && priceNum > 0 && priceNum < normalTotalIdr
      ? Math.round(((normalTotalIdr - priceNum) / normalTotalIdr) * 100)
      : 0

  const handleSubmit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    const normalizedCode = pkgCode.trim().toUpperCase()
    const trimmedName = pkgName.trim()

    if (!normalizedCode || !trimmedName) {
      setFormError('Kode paket dan nama paket wajib diisi.')
      return
    }

    const hasDuplicateCode = existingPackages.some(
      (p) => p.code.trim().toUpperCase() === normalizedCode && p.id !== initialPackage?.id,
    )
    if (hasDuplicateCode) {
      setFormError(`Kode paket "${normalizedCode}" sudah digunakan paket lain.`)
      return
    }

    if (coinsNum < 1) {
      setFormError('Jumlah koin pokok minimal 1 Koin.')
      return
    }
    if (priceNum < 1000) {
      setFormError('Harga paket minimal Rp1.000.')
      return
    }

    setFormError(null)
    setSubmitting(true)
    try {
      const saved = await upsertCoinPackage({
        id: initialPackage?.id,
        code: normalizedCode,
        name: trimmedName,
        coins: coinsNum,
        bonusCoins: bonusNum,
        priceIdr: priceNum,
        description:
          pkgDesc.trim() ||
          `Total ${totalCoins} EVA Coin untuk layanan EVA (${coinsNum} koin pokok + ${bonusNum} bonus).`,
        isPopular: pkgPopular,
        isActive: initialPackage ? initialPackage.isActive : true,
      })
      onSave(saved, isEdit)
    } catch (err) {
      setFormError(err instanceof Error ? err.message : 'Gagal menyimpan data paket.')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <form
      onSubmit={handleSubmit}
      className="mt-3.5 rounded-[10px] border border-[#CBD5E1] bg-[#F8FAFC] p-4 text-xs"
    >
      <div className="flex flex-wrap items-center justify-between gap-2">
        <p className="font-bold text-ink">
          {isEdit
            ? `Edit Paket Bundling Koin (${initialPackage.code})`
            : 'Tambah Paket Bundling Koin Baru'}
        </p>
        {isEdit && (
          <span className="rounded-[5px] bg-[#EEF0FF] px-2 py-0.5 text-[10.5px] font-semibold text-primary">
            Mode Edit
          </span>
        )}
      </div>

      {formError && (
        <div
          role="alert"
          className="mt-3 rounded-[8px] border border-crisis-border bg-crisis-bg px-3 py-2 text-[11.5px] font-medium text-crisis-text"
        >
          {formError}
        </div>
      )}

      <div className="mt-3 grid grid-cols-1 gap-3 sm:grid-cols-3">
        <div>
          <label htmlFor="pkg-code" className="block font-semibold text-ink">
            Kode Paket *
          </label>
          <input
            id="pkg-code"
            type="text"
            required
            value={pkgCode}
            onChange={(e) => {
              setPkgCode(e.target.value.toUpperCase())
              if (formError) setFormError(null)
            }}
            placeholder="COIN-60"
            className="mt-1 h-8 w-full rounded-[6px] border border-[#CBD5E1] bg-white px-2.5 font-mono uppercase text-ink focus:border-primary focus:outline-none"
          />
        </div>
        <div className="sm:col-span-2">
          <label htmlFor="pkg-name" className="block font-semibold text-ink">
            Nama Paket *
          </label>
          <input
            id="pkg-name"
            type="text"
            required
            value={pkgName}
            onChange={(e) => {
              setPkgName(e.target.value)
              if (formError) setFormError(null)
            }}
            placeholder="Paket Curhat Mingguan"
            className="mt-1 h-8 w-full rounded-[6px] border border-[#CBD5E1] bg-white px-2.5 text-ink focus:border-primary focus:outline-none"
          />
        </div>
        <div>
          <label htmlFor="pkg-coins" className="block font-semibold text-ink">
            Koin Pokok
          </label>
          <input
            id="pkg-coins"
            type="number"
            min={1}
            value={pkgCoins}
            onChange={(e) => {
              setPkgCoins(e.target.value)
              if (formError) setFormError(null)
            }}
            className="mt-1 h-8 w-full rounded-[6px] border border-[#CBD5E1] bg-white px-2.5 text-ink focus:border-primary focus:outline-none"
          />
        </div>
        <div>
          <label htmlFor="pkg-bonus" className="block font-semibold text-ink">
            Bonus Koin
          </label>
          <input
            id="pkg-bonus"
            type="number"
            min={0}
            value={pkgBonus}
            onChange={(e) => setPkgBonus(e.target.value)}
            className="mt-1 h-8 w-full rounded-[6px] border border-[#CBD5E1] bg-white px-2.5 text-ink focus:border-primary focus:outline-none"
          />
        </div>
        <div>
          <label htmlFor="pkg-price" className="block font-semibold text-ink">
            Harga Paket (Rp)
          </label>
          <input
            id="pkg-price"
            type="number"
            min={1000}
            step={500}
            value={pkgPrice}
            onChange={(e) => {
              setPkgPrice(e.target.value)
              if (formError) setFormError(null)
            }}
            className="mt-1 h-8 w-full rounded-[6px] border border-[#CBD5E1] bg-white px-2.5 text-ink focus:border-primary focus:outline-none"
          />
        </div>
        <div className="sm:col-span-3">
          <label htmlFor="pkg-desc" className="block font-semibold text-ink">
            Deskripsi Singkat
          </label>
          <input
            id="pkg-desc"
            type="text"
            value={pkgDesc}
            onChange={(e) => setPkgDesc(e.target.value)}
            placeholder="Keterangan benefit paket EVA Coin dan penghematan..."
            className="mt-1 h-8 w-full rounded-[6px] border border-[#CBD5E1] bg-white px-2.5 text-ink focus:border-primary focus:outline-none"
          />
        </div>
      </div>

      {/* Live Preview + Popular Flag */}
      <div className="mt-3 flex flex-col justify-between gap-2.5 rounded-[8px] border border-[#E2E8F0] bg-white px-3 py-2.5 sm:flex-row sm:items-center">
        <label
          htmlFor="pkg-popular"
          className="inline-flex cursor-pointer items-center gap-2 font-semibold text-ink select-none"
        >
          <input
            id="pkg-popular"
            type="checkbox"
            checked={pkgPopular}
            onChange={(e) => setPkgPopular(e.target.checked)}
            className="size-3.5 rounded border-[#CBD5E1] accent-primary"
          />
          <Star aria-hidden="true" className="size-3.5 text-amber-500" />
          <span>Tandai sebagai Paket Populer</span>
        </label>

        <div className="flex flex-wrap items-center gap-1.5 text-[11px] text-ink-soft">
          <span>
            Total: <strong className="text-ink">{totalCoins} Koin</strong>
          </span>
          <span>·</span>
          <span>
            Efektif:{' '}
            <strong className="text-primary">
              ~Rp{effectivePerCoin.toLocaleString('id-ID')}/Koin
            </strong>
          </span>
          {savingsPct > 0 && (
            <span className="rounded-[4px] bg-emerald-50 px-1.5 py-0.5 font-bold text-emerald-700">
              Hemat {savingsPct}%
            </span>
          )}
        </div>
      </div>

      <div className="mt-3 flex justify-end gap-2">
        <button
          type="button"
          onClick={onCancel}
          disabled={submitting}
          className="h-10 cursor-pointer rounded-[6px] border border-[#CBD5E1] bg-white px-3 font-semibold text-ink-soft hover:bg-[#F8FAFC] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary disabled:opacity-50 sm:h-8"
        >
          Batal
        </button>
        <button
          type="submit"
          disabled={submitting}
          className="inline-flex h-10 cursor-pointer items-center gap-1.5 rounded-[6px] bg-primary px-3.5 font-semibold text-white hover:bg-primary-hover focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary disabled:opacity-60 sm:h-8"
        >
          {submitting && <Loader2 className="size-3.5 animate-spin" aria-hidden="true" />}
          <span>{isEdit ? 'Simpan Perubahan' : 'Simpan Paket'}</span>
        </button>
      </div>
    </form>
  )
}

function CoinEconomyConfigForm({
  economyConfig,
  onFeedback,
}: {
  economyConfig: CoinEconomyConfig
  onFeedback: (message: string) => void
}) {
  const [basePriceInput, setBasePriceInput] = useState(String(economyConfig.basePricePerCoinIdr))
  const [freeTrialInput, setFreeTrialInput] = useState(
    String(economyConfig.freeTrialCoinsNewUser),
  )
  const [savingEconomy, setSavingEconomy] = useState(false)
  const [economyError, setEconomyError] = useState<string | null>(null)

  const handleSaveEconomyConfig = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    const basePrice = Math.max(100, Math.round(Number(basePriceInput) || 1000))
    const freeTrial = Math.max(0, Math.round(Number(freeTrialInput) || 0))

    setEconomyError(null)
    setSavingEconomy(true)
    try {
      const saved = await updateCoinEconomyConfig({
        basePricePerCoinIdr: basePrice,
        freeTrialCoinsNewUser: freeTrial,
      })
      onFeedback(
        `Konfigurasi nilai EVA Coin berhasil diperbarui: Rp${saved.basePricePerCoinIdr.toLocaleString('id-ID')}/Koin.`,
      )
    } catch (err) {
      setEconomyError(
        err instanceof Error ? err.message : 'Gagal menyimpan pengaturan kurs koin.',
      )
    } finally {
      setSavingEconomy(false)
    }
  }

  return (
    <form
      onSubmit={handleSaveEconomyConfig}
      className="rounded-[12px] border border-[#E2E8F0] bg-white p-5 lg:col-span-4 lg:self-start"
    >
      <h3 className="text-sm font-bold text-ink">
        Pengaturan Kurs Dasar &amp; Kuota Trial
      </h3>
      <p className="mt-0.5 text-xs text-ink-muted">
        Atur nilai konversi dasar untuk 1 EVA Coin (mata uang Voice AI 1 Koin/mnt &amp; telekonsultasi) dan bonus registrasi awal.
      </p>

      {economyError && (
        <div className="mt-3 rounded-[8px] border border-[#FECACA] bg-[#FEF2F2] px-3 py-2 text-[11px] font-semibold text-[#991B1B]">
          {economyError}
        </div>
      )}

      <div className="mt-4 space-y-3.5 text-xs">
        <div>
          <label htmlFor="coin-base-price" className="block font-semibold text-ink">
            Harga Dasar per 1 EVA Coin - Rp
          </label>
          <input
            id="coin-base-price"
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
          <label htmlFor="coin-free-trial" className="block font-semibold text-ink">
            Bonus Koin Gratis Pengguna Baru (Free Trial)
          </label>
          <input
            id="coin-free-trial"
            type="number"
            min={0}
            max={1000}
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
          disabled={savingEconomy}
          className="inline-flex h-9 w-full cursor-pointer items-center justify-center gap-1.5 rounded-[8px] bg-primary px-4 text-xs font-semibold text-white transition-colors hover:bg-primary-hover disabled:opacity-60"
        >
          {savingEconomy && <Loader2 className="size-3.5 animate-spin" aria-hidden="true" />}
          <span>Simpan Pengaturan Kurs Koin</span>
        </button>
      </div>
    </form>
  )
}

export function AdminCoinPackagesConfigTab({
  db,
  onFeedback,
}: AdminCoinPackagesConfigTabProps) {
  const catalogSectionRef = useRef<HTMLDivElement>(null)

  // Package form & delete confirm state
  const [formMode, setFormMode] = useState<'closed' | 'add' | 'edit'>('closed')
  const [editingPackageId, setEditingPackageId] = useState<string | null>(null)
  const [confirmDeleteId, setConfirmDeleteId] = useState<string | null>(null)
  const [busyPackageId, setBusyPackageId] = useState<string | null>(null)
  const [catalogError, setCatalogError] = useState<string | null>(null)

  const editingPackage =
    editingPackageId !== null
      ? (db.coinPackages.find((p) => p.id === editingPackageId) ?? null)
      : null

  const activePackagesCount = db.coinPackages.filter((pkg) => pkg.isActive).length
  const {
    pageSize,
    safePage,
    paginatedItems: paginatedPackages,
    handlePageChange,
    handlePageSizeChange,
  } = useUrlPagination(db.coinPackages, {
    defaultPageSize: 6,
    scrollTargetRef: catalogSectionRef,
  })

  const handleToggleAddButton = () => {
    setConfirmDeleteId(null)
    setCatalogError(null)
    if (formMode === 'add') {
      setFormMode('closed')
      return
    }
    setEditingPackageId(null)
    setFormMode('add')
  }

  const handleStartEditPackage = (pkg: CoinPackage) => {
    setConfirmDeleteId(null)
    setCatalogError(null)
    setEditingPackageId(pkg.id)
    setFormMode('edit')
    catalogSectionRef.current?.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
  }

  const handleCloseForm = () => {
    setFormMode('closed')
    setEditingPackageId(null)
  }

  const handlePackageSaved = (saved: CoinPackage, isEdit: boolean) => {
    handleCloseForm()
    setCatalogError(null)
    onFeedback(
      isEdit
        ? `Paket koin "${saved.name}" (${saved.code}) berhasil diperbarui.`
        : `Paket koin "${saved.name}" (${saved.code}) berhasil ditambahkan ke katalog top-up.`,
    )
  }

  const handleConfirmDeletePackage = async (pkg: CoinPackage) => {
    setCatalogError(null)
    setBusyPackageId(pkg.id)
    try {
      await deleteCoinPackage(pkg.id)
      setConfirmDeleteId(null)
      if (editingPackageId === pkg.id) {
        handleCloseForm()
      }
      onFeedback(`Paket koin "${pkg.name}" (${pkg.code}) dihapus dari katalog.`)
    } catch (err) {
      setCatalogError(err instanceof Error ? err.message : 'Gagal menghapus paket koin.')
    } finally {
      setBusyPackageId(null)
    }
  }

  const handleTogglePackageActive = async (pkg: CoinPackage) => {
    setCatalogError(null)
    setBusyPackageId(pkg.id)
    try {
      const updated = await toggleCoinPackageActive(pkg.id)
      onFeedback(
        `Paket "${updated.name}" (${updated.code}) sekarang ${updated.isActive ? 'diaktifkan' : 'dinonaktifkan'} di aplikasi.`,
      )
    } catch (err) {
      setCatalogError(
        err instanceof Error ? err.message : 'Gagal mengubah status tayang paket.',
      )
    } finally {
      setBusyPackageId(null)
    }
  }

  return (
    <div className="mt-5 space-y-5">
      {/* Summary Header Banner */}
      <div className="flex flex-col justify-between gap-3 rounded-[12px] border border-[#E2E8F0] bg-white p-4 sm:flex-row sm:items-center">
        <div className="flex items-start gap-3">
          <span className="mt-0.5 flex size-9 shrink-0 items-center justify-center rounded-[8px] bg-[#EEF0FF] text-primary">
            <Sparkles className="size-4" />
          </span>
          <div>
            <h2 className="text-sm font-bold text-ink">
              Konfigurasi Ekonomi EVA Coin &amp; Katalog Paket Aplikasi
            </h2>
            <p className="text-xs text-ink-muted">
              1 Koin berlaku sebagai mata uang terpadu EVA (1 menit sesi suara AI maupun telekonsultasi psikolog). Pengaturan di bawah ini disinkronkan ke halaman Top-Up aplikasi mobile.
            </p>
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-2 text-xs">
          <span className="inline-flex items-center gap-1.5 rounded-[6px] border border-[#E2E8F0] bg-[#F8FAFC] px-2.5 py-1 font-semibold text-ink">
            <Coins className="size-3.5 text-primary" />
            Kurs Dasar: Rp{db.coinEconomyConfig.basePricePerCoinIdr.toLocaleString('id-ID')}/Koin
          </span>
          <span className="inline-flex items-center rounded-[6px] bg-emerald-50 px-2.5 py-1 font-semibold text-emerald-800">
            {activePackagesCount} Paket Aktif di App
          </span>
        </div>
      </div>

      {/* Main Grid: Base Rate Configuration + Bundling Packages Catalog */}
      <div className="grid grid-cols-1 gap-5 lg:grid-cols-12">
        {/* Left: Economy Config Form */}
        <CoinEconomyConfigForm
          key={`${db.coinEconomyConfig.basePricePerCoinIdr}-${db.coinEconomyConfig.freeTrialCoinsNewUser}-${db.coinEconomyConfig.updatedAt}`}
          economyConfig={db.coinEconomyConfig}
          onFeedback={onFeedback}
        />

        {/* Right: Coin Bundling Packages */}
        <div
          ref={catalogSectionRef}
          className="rounded-[12px] border border-[#E2E8F0] bg-white p-5 lg:col-span-8"
        >
          <div className="flex flex-col justify-between gap-3 border-b border-[#E2E8F0] pb-3.5 sm:flex-row sm:items-center">
            <div className="min-w-0 flex-1">
              <h3 className="text-sm font-bold text-ink">
                Katalog Paket Bundling Top-Up Koin
              </h3>
              <p className="text-xs text-ink-muted">
                Kelola paket pembelian EVA Coin pada menu Top-Up aplikasi mobile EVA.
              </p>
            </div>
            <button
              type="button"
              onClick={handleToggleAddButton}
              className="inline-flex h-10 shrink-0 cursor-pointer items-center gap-1.5 self-start rounded-[8px] border border-[#CBD5E1] bg-[#F8FAFC] px-3 text-xs font-semibold text-ink transition-colors hover:border-primary hover:text-primary focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary sm:h-8 sm:self-auto"
            >
              <Plus aria-hidden="true" className="size-3.5" />
              <span>{formMode === 'add' ? 'Tutup Form' : 'Tambah Paket'}</span>
            </button>
          </div>

          {catalogError && (
            <div className="mt-3 flex items-center gap-2 rounded-[8px] border border-[#FECACA] bg-[#FEF2F2] px-3 py-2 text-xs font-semibold text-[#991B1B]">
              <AlertCircle className="size-4 shrink-0" aria-hidden="true" />
              <span>{catalogError}</span>
            </div>
          )}

          {formMode !== 'closed' && (
            <CoinPackageForm
              key={formMode === 'edit' ? (editingPackage?.id ?? 'edit') : 'new'}
              initialPackage={formMode === 'edit' ? editingPackage : null}
              basePricePerCoinIdr={db.coinEconomyConfig.basePricePerCoinIdr}
              existingPackages={db.coinPackages}
              onSave={handlePackageSaved}
              onCancel={handleCloseForm}
            />
          )}

          {db.coinPackages.length === 0 ? (
            <div className="mt-4 rounded-[10px] border border-dashed border-[#CBD5E1] bg-[#F8FAFC] p-6 text-center text-xs text-ink-muted">
              Belum ada paket koin di katalog. Klik &ldquo;Tambah Paket&rdquo; untuk membuat paket top-up baru.
            </div>
          ) : (
            <div className="mt-4 space-y-4">
              <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                {paginatedPackages.map((pkg) => {
                const totalCoins = pkg.coins + pkg.bonusCoins
                const effectivePerCoin =
                  totalCoins > 0 ? Math.round(pkg.priceIdr / totalCoins) : 0
                const isEditing = formMode === 'edit' && editingPackage?.id === pkg.id
                const isConfirmingDelete = confirmDeleteId === pkg.id

                return (
                  <div
                    key={pkg.id}
                    className={cn(
                      'flex flex-col justify-between rounded-[10px] border p-3.5 transition-colors',
                      isEditing
                        ? 'border-primary bg-[#EEF0FF]/30 ring-1 ring-primary/15'
                        : pkg.isActive
                          ? 'border-[#E2E8F0] bg-[#F8FAFC]/60'
                          : 'border-dashed border-[#CBD5E1] bg-[#F8FAFC]',
                    )}
                  >
                    <div>
                      <div className="flex items-start justify-between gap-2">
                        <div>
                          <div className="flex flex-wrap items-center gap-1.5">
                            <span className="font-mono text-[10px] font-bold text-primary">
                              {pkg.code}
                            </span>
                            {pkg.isPopular && (
                              <span className="rounded-[4px] bg-amber-100 px-1.5 py-0.5 text-[10px] font-bold text-amber-800">
                                Populer
                              </span>
                            )}
                            {isEditing && (
                              <span className="rounded-[4px] bg-primary px-1.5 py-0.5 text-[10px] font-bold text-white">
                                Sedang Diedit
                              </span>
                            )}
                          </div>
                          <h4 className="mt-0.5 text-xs font-bold text-ink">{pkg.name}</h4>
                        </div>

                        <span className="text-sm font-extrabold text-primary">
                          Rp{pkg.priceIdr.toLocaleString('id-ID')}
                        </span>
                      </div>

                      <div className="mt-2 flex flex-wrap items-center gap-1.5 text-[11px]">
                        <span className="rounded-[5px] bg-white px-2 py-0.5 font-semibold text-ink shadow-2xs">
                          {pkg.coins} Koin
                        </span>
                        {pkg.bonusCoins > 0 && (
                          <span className="rounded-[5px] bg-emerald-50 px-2 py-0.5 font-bold text-emerald-700">
                            +{pkg.bonusCoins} Bonus Koin
                          </span>
                        )}
                        <span className="text-ink-muted">
                          · ~Rp{effectivePerCoin.toLocaleString('id-ID')}/Koin
                        </span>
                      </div>

                      <p className="mt-2 text-[11px] leading-snug text-ink-muted">
                        {pkg.description}
                      </p>
                    </div>

                    <div className="mt-3 border-t border-[#E2E8F0] pt-2.5 text-[11.5px]">
                      {isConfirmingDelete ? (
                        <div className="flex flex-wrap items-center justify-between gap-2 rounded-[8px] border border-[#FECACA] bg-[#FEF2F2] px-2.5 py-1.5">
                          <span className="font-semibold text-[#991B1B]">
                            Hapus paket {pkg.code}?
                          </span>
                          <div className="flex items-center gap-1.5">
                            <button
                              type="button"
                              disabled={busyPackageId === pkg.id}
                              onClick={() => void handleConfirmDeletePackage(pkg)}
                              className="inline-flex h-10 cursor-pointer items-center rounded-[6px] bg-[#B91C1C] px-2.5 text-[11px] font-semibold text-white transition-colors hover:bg-[#991B1B] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#B91C1C] disabled:opacity-50 sm:h-7"
                            >
                              Ya, Hapus
                            </button>
                            <button
                              type="button"
                              disabled={busyPackageId === pkg.id}
                              onClick={() => setConfirmDeleteId(null)}
                              className="inline-flex h-10 cursor-pointer items-center rounded-[6px] border border-[#CBD5E1] bg-white px-2.5 text-[11px] font-semibold text-ink transition-colors hover:bg-[#F8FAFC] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary disabled:opacity-50 sm:h-7"
                            >
                              Batal
                            </button>
                          </div>
                        </div>
                      ) : (
                        <div className="flex items-center justify-between gap-2">
                          <button
                            type="button"
                            role="switch"
                            aria-checked={pkg.isActive}
                            aria-label={`Ubah status tayang ${pkg.name}`}
                            disabled={busyPackageId === pkg.id}
                            onClick={() => void handleTogglePackageActive(pkg)}
                            className="inline-flex min-h-[44px] cursor-pointer items-center gap-2 rounded-[6px] pr-1 text-left focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary disabled:opacity-50 sm:min-h-[32px]"
                          >
                            <span
                              aria-hidden="true"
                              className={cn(
                                'relative inline-flex h-5 w-9 shrink-0 items-center rounded-full border transition-colors',
                                pkg.isActive
                                  ? 'border-emerald-600 bg-emerald-600'
                                  : 'border-[#CBD5E1] bg-slate-200',
                              )}
                            >
                              <span
                                className={cn(
                                  'inline-block size-3.5 rounded-full bg-white shadow-xs transition-transform',
                                  pkg.isActive ? 'translate-x-[18px]' : 'translate-x-[2px]',
                                )}
                              />
                            </span>
                            <span
                              className={cn(
                                'font-semibold',
                                pkg.isActive ? 'text-emerald-800' : 'text-ink-muted',
                              )}
                            >
                              {pkg.isActive ? 'Tampil di App' : 'Nonaktif'}
                            </span>
                          </button>

                          <div className="flex shrink-0 items-center gap-1.5">
                            <button
                              type="button"
                              aria-label={`Edit paket ${pkg.name}`}
                              onClick={() => handleStartEditPackage(pkg)}
                              className={cn(
                                'inline-flex h-11 cursor-pointer items-center gap-1.5 rounded-[7px] border px-3 text-[11.5px] font-semibold transition-colors focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary sm:h-8',
                                isEditing
                                  ? 'border-primary bg-[#EEF0FF] text-primary'
                                  : 'border-[#CBD5E1] bg-white text-ink hover:border-primary/60 hover:bg-[#F8FAFC] hover:text-primary',
                              )}
                            >
                              <Pencil aria-hidden="true" className="size-3.5" />
                              <span>Edit</span>
                            </button>
                            <button
                              type="button"
                              aria-label={`Hapus paket ${pkg.name}`}
                              title={`Hapus paket ${pkg.name}`}
                              onClick={() => setConfirmDeleteId(pkg.id)}
                              className="inline-flex size-11 cursor-pointer items-center justify-center rounded-[7px] border border-[#FECACA] bg-[#FEF2F2] text-[#B91C1C] transition-colors hover:border-[#FCA5A5] hover:bg-[#FEE2E2] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-crisis-text sm:size-8"
                            >
                              <Trash2 aria-hidden="true" className="size-3.5" />
                            </button>
                          </div>
                        </div>
                      )}
                    </div>
                  </div>
                )
              })}
              </div>

              <TablePagination
                currentPage={safePage}
                totalItems={db.coinPackages.length}
                pageSize={pageSize}
                pageSizeOptions={[4, 6, 12, 24]}
                itemLabel="paket koin"
                ariaLabel="Paginasi katalog paket koin"
                onPageChange={handlePageChange}
                onPageSizeChange={handlePageSizeChange}
              />
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
