import { CheckCircle2, Coins, Loader2, Search, User as UserIcon, X } from 'lucide-react'
import { useMemo, useState, type FormEvent } from 'react'
import { useBodyScrollLock } from '@/hooks/useBodyScrollLock'
import { cn } from '@/lib/cn'
import {
  topUpUserCoins,
  type CoinEconomyConfig,
  type CoinPackage,
  type CoinPaymentMethod,
  type GeneralAppUser,
} from '@/lib/portalStore'

interface AdminCoinTopupModalProps {
  isOpen: boolean
  users: GeneralAppUser[]
  coinPackages: CoinPackage[]
  economyConfig: CoinEconomyConfig
  preselectedUser?: GeneralAppUser | null
  onClose: () => void
  onSuccess: (message: string) => void
}

const CONVENTIONAL_PAYMENT_METHODS: Array<{
  id: CoinPaymentMethod
  label: string
  hint: string
}> = [
  { id: 'Transfer Bank', label: 'Transfer Bank', hint: 'BCA / Mandiri / BRI / BNI' },
  { id: 'QRIS', label: 'QRIS', hint: 'Scan QR konfirmasi Admin' },
  { id: 'Tunai', label: 'Tunai', hint: 'Pembayaran langsung' },
  { id: 'Grant Admin (Gratis)', label: 'Grant Gratis (Rp0)', hint: 'Bonus / kompensasi Admin' },
]

export function AdminCoinTopupModal({
  isOpen,
  users,
  coinPackages,
  economyConfig,
  preselectedUser = null,
  onClose,
  onSuccess,
}: AdminCoinTopupModalProps) {
  useBodyScrollLock(isOpen)

  const activePackages = useMemo(() => coinPackages.filter((p) => p.isActive), [coinPackages])
  const defaultPkg = activePackages[0] ?? null

  const [selectedUserId, setSelectedUserId] = useState<string>(
    () => preselectedUser?.id ?? users[0]?.id ?? '',
  )
  const [userSearch, setUserSearch] = useState('')
  const [inputMode, setInputMode] = useState<'preset' | 'manual'>(() =>
    defaultPkg ? 'preset' : 'manual',
  )
  const [selectedPackageId, setSelectedPackageId] = useState<string>(defaultPkg?.id ?? '')
  const [manualCoinsInput, setManualCoinsInput] = useState('150')
  const [paymentMethod, setPaymentMethod] = useState<CoinPaymentMethod>('Transfer Bank')
  const [customAmountIdrInput, setCustomAmountIdrInput] = useState<string>(() =>
    defaultPkg ? String(defaultPkg.priceIdr) : String(150 * economyConfig.basePricePerCoinIdr),
  )
  const [adminNotes, setAdminNotes] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [errorMsg, setErrorMsg] = useState<string | null>(null)

  const filteredUsers = useMemo(() => {
    const q = userSearch.trim().toLowerCase()
    if (!q) return users
    return users.filter(
      (u) =>
        u.displayName.toLowerCase().includes(q) ||
        u.email.toLowerCase().includes(q) ||
        u.userCode.toLowerCase().includes(q),
    )
  }, [users, userSearch])

  if (!isOpen) return null

  const targetUser =
    preselectedUser ?? users.find((u) => u.id === selectedUserId) ?? filteredUsers[0] ?? null

  const selectedPackage =
    activePackages.find((p) => p.id === selectedPackageId) ?? activePackages[0] ?? null

  const effectiveCoins =
    inputMode === 'preset' && selectedPackage
      ? selectedPackage.coins + selectedPackage.bonusCoins
      : Math.max(0, Math.trunc(Number(manualCoinsInput) || 0))

  const isGrantFree = paymentMethod === 'Grant Admin (Gratis)'
  const effectiveAmountIdr = isGrantFree
    ? 0
    : Math.max(0, Math.trunc(Number(customAmountIdrInput) || 0))

  const handleSwitchMode = (nextMode: 'preset' | 'manual') => {
    setInputMode(nextMode)
    setErrorMsg(null)
    if (nextMode === 'preset' && selectedPackage) {
      setCustomAmountIdrInput(String(selectedPackage.priceIdr))
    } else if (nextMode === 'manual') {
      const coinsVal = Math.max(0, Math.trunc(Number(manualCoinsInput) || 0))
      setCustomAmountIdrInput(String(coinsVal * economyConfig.basePricePerCoinIdr))
    }
  }

  const handleSelectPackage = (pkg: CoinPackage) => {
    setSelectedPackageId(pkg.id)
    setErrorMsg(null)
    if (!isGrantFree) {
      setCustomAmountIdrInput(String(pkg.priceIdr))
    }
  }

  const handleManualCoinsChange = (raw: string) => {
    setManualCoinsInput(raw)
    setErrorMsg(null)
    if (!isGrantFree) {
      const parsed = Math.max(0, Math.trunc(Number(raw) || 0))
      setCustomAmountIdrInput(String(parsed * economyConfig.basePricePerCoinIdr))
    }
  }

  const handlePaymentMethodChange = (method: CoinPaymentMethod) => {
    setPaymentMethod(method)
    setErrorMsg(null)
    if (method === 'Grant Admin (Gratis)') {
      setCustomAmountIdrInput('0')
    } else if (inputMode === 'preset' && selectedPackage) {
      setCustomAmountIdrInput(String(selectedPackage.priceIdr))
    } else {
      const parsed = Math.max(0, Math.trunc(Number(manualCoinsInput) || 0))
      setCustomAmountIdrInput(String(parsed * economyConfig.basePricePerCoinIdr))
    }
  }

  const handleSubmit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    if (submitting) return

    if (!targetUser) {
      setErrorMsg('Pilih pengguna tujuan terlebih dahulu.')
      return
    }
    if (effectiveCoins <= 0) {
      setErrorMsg('Jumlah koin yang ditambahkan harus lebih dari 0.')
      return
    }

    const packageLabel =
      inputMode === 'preset' && selectedPackage
        ? `${selectedPackage.name} (+${effectiveCoins} Koin)`
        : isGrantFree
          ? `Grant Admin (+${effectiveCoins} Koin)`
          : `Top-Up Konvensional (+${effectiveCoins} Koin)`

    setErrorMsg(null)
    setSubmitting(true)
    try {
      const result = await topUpUserCoins({
        userId: targetUser.id,
        coinsGranted: effectiveCoins,
        amountIdr: effectiveAmountIdr,
        paymentMethod,
        packageName: packageLabel,
        adminNotes: adminNotes.trim() || undefined,
      })
      onSuccess(
        `Berhasil menambahkan +${result.transaction.coinsGranted} Koin ke ${result.user.displayName} (Saldo baru: ${result.user.coinBalance} Koin).`,
      )
      onClose()
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : 'Gagal memproses penambahan koin.')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="coin-topup-modal-title"
      className="fixed inset-0 z-50 flex items-center justify-center bg-ink/50 p-3 sm:p-4"
    >
      <div className="flex max-h-[92dvh] w-full max-w-xl flex-col overflow-hidden rounded-[16px] border border-[#E2E8F0] bg-white shadow-2xl">
        <div className="flex items-start justify-between gap-3 border-b border-[#E2E8F0] px-5 py-4">
          <div className="flex items-center gap-2.5">
            <span className="flex size-9 shrink-0 items-center justify-center rounded-[10px] bg-[#EEF0FF] text-primary">
              <Coins className="size-4.5" />
            </span>
            <div>
              <h2 id="coin-topup-modal-title" className="text-sm font-bold text-ink sm:text-base">
                Tambah Koin Pengguna (Top-Up Konvensional)
              </h2>
              <p className="text-xs text-ink-muted">
                Konfirmasi top-up manual ke Admin EVA dan kreditkan koin langsung ke akun pengguna.
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            aria-label="Tutup modal top-up koin"
            className="inline-flex size-8 cursor-pointer items-center justify-center rounded-[8px] border border-[#CBD5E1] text-ink-muted hover:bg-slate-50 hover:text-ink"
          >
            <X className="size-4" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4 overflow-y-auto p-5 text-xs">
          {errorMsg && (
            <div className="rounded-[8px] border border-crisis-border bg-crisis-bg px-3 py-2 text-xs font-medium text-crisis-text">
              {errorMsg}
            </div>
          )}

          {preselectedUser ? (
            <div className="flex items-center justify-between gap-3 rounded-[10px] border border-[#E2E8F0] bg-[#F8FAFC] p-3">
              <div className="flex min-w-0 items-center gap-2.5">
                <span className="flex size-8 shrink-0 items-center justify-center rounded-full bg-primary/10 text-primary">
                  <UserIcon className="size-4" />
                </span>
                <div className="min-w-0">
                  <p className="truncate font-bold text-ink">{preselectedUser.displayName}</p>
                  <p className="truncate text-[11px] text-ink-muted">
                    {preselectedUser.email} · {preselectedUser.userCode}
                  </p>
                </div>
              </div>
              <span className="shrink-0 rounded-[6px] bg-[#EEF0FF] px-2.5 py-1 text-[11px] font-bold text-primary">
                Saldo: {preselectedUser.coinBalance ?? 0} Koin
              </span>
            </div>
          ) : (
            <div className="space-y-2 rounded-[10px] border border-[#E2E8F0] bg-[#F8FAFC] p-3">
              <label htmlFor="topup-user-select" className="block font-semibold text-ink">
                Pilih Pengguna Tujuan *
              </label>
              <div className="relative">
                <Search className="pointer-events-none absolute top-1/2 left-2.5 size-3.5 -translate-y-1/2 text-ink-muted" />
                <input
                  type="search"
                  value={userSearch}
                  onChange={(e) => setUserSearch(e.target.value)}
                  placeholder="Filter nama, email, atau kode pengguna..."
                  className="h-8 w-full rounded-[8px] border border-[#CBD5E1] bg-white pr-3 pl-8 text-xs text-ink focus:border-primary focus:outline-none"
                />
              </div>
              <select
                id="topup-user-select"
                value={targetUser?.id ?? ''}
                onChange={(e) => setSelectedUserId(e.target.value)}
                className="h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-2.5 text-xs font-medium text-ink focus:border-primary focus:outline-none"
              >
                {filteredUsers.length === 0 ? (
                  <option value="">Tidak ada pengguna cocok</option>
                ) : (
                  filteredUsers.map((u) => (
                    <option key={u.id} value={u.id}>
                      {u.displayName} ({u.email}) — Saldo: {u.coinBalance ?? 0} Koin
                    </option>
                  ))
                )}
              </select>
            </div>
          )}

          <div>
            <span className="mb-1.5 block font-semibold text-ink">Sumber Nominal Koin</span>
            <div className="grid grid-cols-2 gap-2 rounded-[8px] bg-[#F1F5F9] p-1">
              <button
                type="button"
                onClick={() => handleSwitchMode('preset')}
                className={cn(
                  'h-8 cursor-pointer rounded-[6px] text-xs font-semibold transition-colors',
                  inputMode === 'preset'
                    ? 'bg-white text-ink shadow-2xs'
                    : 'text-ink-muted hover:text-ink',
                )}
              >
                Pilih Paket Preset
              </button>
              <button
                type="button"
                onClick={() => handleSwitchMode('manual')}
                className={cn(
                  'h-8 cursor-pointer rounded-[6px] text-xs font-semibold transition-colors',
                  inputMode === 'manual'
                    ? 'bg-white text-ink shadow-2xs'
                    : 'text-ink-muted hover:text-ink',
                )}
              >
                Input Manual Koin
              </button>
            </div>
          </div>

          {inputMode === 'preset' && activePackages.length > 0 ? (
            <div className="grid gap-2 sm:grid-cols-2">
              {activePackages.map((pkg) => {
                const isSelected = selectedPackage?.id === pkg.id
                const total = pkg.coins + pkg.bonusCoins
                return (
                  <button
                    key={pkg.id}
                    type="button"
                    onClick={() => handleSelectPackage(pkg)}
                    className={cn(
                      'flex cursor-pointer flex-col items-start rounded-[10px] border p-3 text-left transition-all',
                      isSelected
                        ? 'border-primary bg-[#EEF0FF]/60 ring-1 ring-primary/20'
                        : 'border-[#E2E8F0] bg-white hover:border-primary/40',
                    )}
                  >
                    <div className="flex w-full items-center justify-between gap-2">
                      <span className="font-bold text-ink">{pkg.name}</span>
                      <span className="rounded-[5px] bg-[#EEF0FF] px-2 py-0.5 text-[11px] font-bold text-primary">
                        +{total} Koin
                      </span>
                    </div>
                    <span className="mt-1 text-[11px] font-semibold text-ink-soft">
                      Rp{pkg.priceIdr.toLocaleString('id-ID')}
                      {pkg.bonusCoins > 0 && ` (Termasuk +${pkg.bonusCoins} bonus)`}
                    </span>
                  </button>
                )
              })}
            </div>
          ) : (
            <div>
              <label htmlFor="manual-coins-input" className="mb-1 block font-semibold text-ink">
                Jumlah Koin yang Ditambahkan *
              </label>
              <div className="flex items-center gap-2">
                <input
                  id="manual-coins-input"
                  type="number"
                  min={1}
                  max={100000}
                  value={manualCoinsInput}
                  onChange={(e) => handleManualCoinsChange(e.target.value)}
                  className="h-9 w-full rounded-[8px] border border-[#CBD5E1] px-3 font-mono text-xs font-bold text-ink focus:border-primary focus:outline-none"
                />
                <span className="shrink-0 text-xs font-semibold text-ink-muted">Koin EVA</span>
              </div>
              <p className="mt-1 text-[11px] text-ink-muted">
                Acuan kurs saat ini: Rp{economyConfig.basePricePerCoinIdr.toLocaleString('id-ID')} / Koin
              </p>
            </div>
          )}

          <div className="grid gap-3 sm:grid-cols-2">
            <div>
              <label htmlFor="topup-payment-method" className="mb-1 block font-semibold text-ink">
                Metode Pembayaran Konvensional
              </label>
              <select
                id="topup-payment-method"
                value={paymentMethod}
                onChange={(e) => handlePaymentMethodChange(e.target.value as CoinPaymentMethod)}
                className="h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-2.5 text-xs font-medium text-ink focus:border-primary focus:outline-none"
              >
                {CONVENTIONAL_PAYMENT_METHODS.map((m) => (
                  <option key={m.id} value={m.id}>
                    {m.label} — {m.hint}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label htmlFor="topup-amount-idr" className="mb-1 block font-semibold text-ink">
                Nominal Pembayaran Diterima (Rp)
              </label>
              <input
                id="topup-amount-idr"
                type="number"
                min={0}
                disabled={isGrantFree}
                value={isGrantFree ? '0' : customAmountIdrInput}
                onChange={(e) => setCustomAmountIdrInput(e.target.value)}
                className={cn(
                  'h-9 w-full rounded-[8px] border border-[#CBD5E1] px-3 font-mono text-xs font-semibold text-ink focus:border-primary focus:outline-none',
                  isGrantFree && 'cursor-not-allowed bg-slate-100 text-ink-muted',
                )}
              />
            </div>
          </div>

          <div>
            <label htmlFor="topup-admin-notes" className="mb-1 block font-semibold text-ink">
              Catatan Admin / Referensi Bukti Transfer (Opsional)
            </label>
            <input
              id="topup-admin-notes"
              type="text"
              value={adminNotes}
              onChange={(e) => setAdminNotes(e.target.value)}
              placeholder="Misal: Transfer BCA a.n. Anindya dikonfirmasi Admin via WhatsApp"
              className="h-9 w-full rounded-[8px] border border-[#CBD5E1] px-3 text-xs text-ink placeholder:text-ink-muted/70 focus:border-primary focus:outline-none"
            />
          </div>

          {targetUser && (
            <div className="flex flex-wrap items-center justify-between gap-2 rounded-[10px] border border-[#C7D2FE] bg-[#EEF0FF]/50 px-3.5 py-2.5 text-xs">
              <div>
                <span className="text-ink-muted">Proyeksi Saldo Baru: </span>
                <strong className="font-bold text-primary">
                  {(targetUser.coinBalance ?? 0).toLocaleString('id-ID')} ➔{' '}
                  {((targetUser.coinBalance ?? 0) + effectiveCoins).toLocaleString('id-ID')} Koin
                </strong>
              </div>
              <span className="font-bold text-ink">
                {isGrantFree ? 'Gratis (Grant Admin)' : `Rp${effectiveAmountIdr.toLocaleString('id-ID')}`}
              </span>
            </div>
          )}

          <div className="flex items-center justify-end gap-2 border-t border-[#E2E8F0] pt-3.5">
            <button
              type="button"
              onClick={onClose}
              className="inline-flex h-9 cursor-pointer items-center rounded-[8px] border border-[#CBD5E1] bg-white px-4 text-xs font-semibold text-ink hover:bg-slate-50"
            >
              Batal
            </button>
            <button
              type="submit"
              disabled={submitting || !targetUser || effectiveCoins <= 0}
              className="inline-flex h-9 cursor-pointer items-center gap-1.5 rounded-[8px] bg-primary px-4 text-xs font-semibold text-white shadow-2xs transition-colors hover:bg-primary-hover disabled:cursor-not-allowed disabled:opacity-50"
            >
              {submitting ? (
                <Loader2 className="size-3.5 animate-spin" />
              ) : (
                <CheckCircle2 className="size-3.5" />
              )}
              <span>Tambahkan +{effectiveCoins} Koin</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
