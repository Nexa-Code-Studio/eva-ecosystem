import { Coins, Plus, Sparkles } from 'lucide-react'
import { useState, type FormEvent } from 'react'
import { cn } from '@/lib/cn'
import {
  toggleCoinPackageActive,
  updateCoinEconomyConfig,
  upsertCoinPackage,
  type PortalDatabase,
} from '@/lib/portalStore'

interface AdminCoinPackagesConfigTabProps {
  db: PortalDatabase
  onFeedback: (message: string) => void
}

export function AdminCoinPackagesConfigTab({
  db,
  onFeedback,
}: AdminCoinPackagesConfigTabProps) {
  // Economy config state
  const [basePriceInput, setBasePriceInput] = useState(
    String(db.coinEconomyConfig.basePricePerCoinIdr),
  )
  const [freeTrialInput, setFreeTrialInput] = useState(
    String(db.coinEconomyConfig.freeTrialCoinsNewUser),
  )

  // New package form state
  const [showAddPackage, setShowAddPackage] = useState(false)
  const [pkgCode, setPkgCode] = useState('')
  const [pkgName, setPkgName] = useState('')
  const [pkgCoins, setPkgCoins] = useState('50')
  const [pkgBonus, setPkgBonus] = useState('10')
  const [pkgPrice, setPkgPrice] = useState('45000')
  const [pkgDesc, setPkgDesc] = useState('')

  const activePackagesCount = db.coinPackages.filter((pkg) => pkg.isActive).length

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
              Konfigurasi Ekonomi Koin Suara &amp; Katalog Paket Aplikasi
            </h2>
            <p className="text-xs text-ink-muted">
              1 Koin setara dengan 1 menit sesi berbicara suara bersama EVA. Pengaturan di bawah ini disinkronkan ke halaman Top-Up aplikasi mobile.
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
        <form
          onSubmit={handleSaveEconomyConfig}
          className="rounded-[12px] border border-[#E2E8F0] bg-white p-5 lg:col-span-4"
        >
          <h3 className="text-sm font-bold text-ink">
            Pengaturan Kurs Dasar &amp; Kuota Trial
          </h3>
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
              <h3 className="text-sm font-bold text-ink">
                Katalog Paket Bundling Top-Up Koin
              </h3>
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
                        <h4 className="mt-0.5 text-xs font-bold text-ink">{pkg.name}</h4>
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
    </div>
  )
}

