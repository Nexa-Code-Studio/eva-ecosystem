import {
  Calculator,
  CheckCircle2,
  Clock,
  Loader2,
  Percent,
  Save,
  Sliders,
} from 'lucide-react'
import { useEffect, useMemo, useState, type FormEvent } from 'react'
import { useSearchParams } from 'react-router'
import { cn } from '@/lib/cn'
import {
  STANDARD_SESSION_DURATION_MINUTES,
  calculatePricingBreakdown,
  fetchActivePlatformPricing,
  fetchCoinEconomyConfig,
  fetchCoinPackages,
  savePlatformPricingConfig,
  type PlatformPricingConfig,
  type PortalDatabase,
} from '@/lib/portalStore'
import { AdminCoinPackagesConfigTab } from './AdminCoinPackagesConfigTab'

type SettingsSubTab = 'pricing' | 'coins_catalog'

interface AdminPlatformSettingsModuleProps {
  db: PortalDatabase
  onFeedback: (message: string) => void
}

function formatCoins(value: number): string {
  return `${Math.round(value).toLocaleString('id-ID')} Koin`
}

function formatIdr(value: number): string {
  return `Rp${Math.round(value).toLocaleString('id-ID')}`
}

interface PricingSettingsFormProps {
  pricingConfig: PlatformPricingConfig
  basePricePerCoinIdr: number
  onFeedback: (message: string) => void
}

function PricingSettingsForm({
  pricingConfig,
  basePricePerCoinIdr,
  onFeedback,
}: PricingSettingsFormProps) {
  const [priceInput, setPriceInput] = useState(String(pricingConfig.pricePerSession))
  const [extensionPriceInput, setExtensionPriceInput] = useState(
    String(pricingConfig.extensionPricePerSession),
  )
  const [counselorShareInput, setCounselorShareInput] = useState(
    String(pricingConfig.counselorSharePercentage),
  )
  const [platformFeeInput, setPlatformFeeInput] = useState(
    String(pricingConfig.platformFeePercentage),
  )
  const [notesInput, setNotesInput] = useState(pricingConfig.notes ?? '')
  const [errorMsg, setErrorMsg] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  const safeCoinRateIdr = Math.max(1, Math.round(basePricePerCoinIdr) || 1000)
  const parsedPrice = Math.max(0, Math.round(Number(priceInput) || 0))
  const parsedExtensionPrice = Math.max(0, Math.round(Number(extensionPriceInput) || 0))
  const parsedCounselorShare = Math.min(100, Math.max(0, Number(counselorShareInput) || 0))
  const parsedPlatformFee = Math.min(100, Math.max(0, Number(platformFeeInput) || 0))
  const totalSharePct = Math.round((parsedCounselorShare + parsedPlatformFee) * 100) / 100
  const isShareValid = Math.abs(totalSharePct - 100) < 0.01

  const preview30Min = useMemo(
    () =>
      calculatePricingBreakdown(
        {
          sessionDurationMinutes: STANDARD_SESSION_DURATION_MINUTES,
          pricePerSession: parsedPrice,
          counselorSharePercentage: parsedCounselorShare,
          platformFeePercentage: parsedPlatformFee,
          extensionPricePerSession: parsedExtensionPrice,
        },
        false,
      ),
    [parsedPrice, parsedCounselorShare, parsedPlatformFee, parsedExtensionPrice],
  )

  const preview60Min = useMemo(
    () =>
      calculatePricingBreakdown(
        {
          sessionDurationMinutes: STANDARD_SESSION_DURATION_MINUTES,
          pricePerSession: parsedPrice,
          counselorSharePercentage: parsedCounselorShare,
          platformFeePercentage: parsedPlatformFee,
          extensionPricePerSession: parsedExtensionPrice,
        },
        true,
      ),
    [parsedPrice, parsedCounselorShare, parsedPlatformFee, parsedExtensionPrice],
  )

  const handleCounselorShareChange = (val: string) => {
    setCounselorShareInput(val)
    const num = Number(val)
    if (!Number.isNaN(num) && num >= 0 && num <= 100) {
      setPlatformFeeInput(String(Math.round((100 - num) * 100) / 100))
    }
    if (errorMsg) setErrorMsg(null)
  }

  const handlePlatformFeeChange = (val: string) => {
    setPlatformFeeInput(val)
    const num = Number(val)
    if (!Number.isNaN(num) && num >= 0 && num <= 100) {
      setCounselorShareInput(String(Math.round((100 - num) * 100) / 100))
    }
    if (errorMsg) setErrorMsg(null)
  }

  const handleSubmit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    if (saving) return
    if (!isShareValid) {
      setErrorMsg('Total persentase Hak Psikolog + Fee Platform harus tepat 100%.')
      return
    }
    if (parsedPrice <= 0) {
      setErrorMsg('Tarif dasar per sesi 30 menit harus lebih dari 0 Koin.')
      return
    }

    setErrorMsg(null)
    setSaving(true)
    try {
      const saved = await savePlatformPricingConfig(
        {
          session_duration_minutes: STANDARD_SESSION_DURATION_MINUTES,
          price_per_session: parsedPrice,
          counselor_share_percentage: parsedCounselorShare,
          platform_fee_percentage: parsedPlatformFee,
          extension_price_per_session: parsedExtensionPrice,
          notes: notesInput.trim() || null,
        },
        pricingConfig.id,
      )
      onFeedback(
        `Kebijakan tarif platform berhasil diperbarui: ${formatCoins(saved.pricePerSession)} / 30 menit (${saved.counselorSharePercentage}% Psikolog : ${saved.platformFeePercentage}% Platform).`,
      )
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : 'Gagal menyimpan pengaturan platform.')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="mt-5 grid grid-cols-1 gap-5 lg:grid-cols-12 lg:items-start">
      {/* Form Pengaturan Master */}
      <form
        onSubmit={handleSubmit}
        className="rounded-[12px] border border-[#E2E8F0] bg-white p-5 lg:col-span-6"
      >
        <div className="flex flex-wrap items-center justify-between gap-2 border-b border-[#E2E8F0] pb-3.5">
          <div className="flex items-center gap-2">
            <span className="flex size-8 items-center justify-center rounded-[8px] bg-[#EEF0FF] text-primary">
              <Sliders className="size-4" />
            </span>
            <div>
              <h2 className="text-sm font-bold text-ink">Master Tarif &amp; Skema Bagi Hasil</h2>
              <p className="text-[11px] text-ink-muted">
                Diterapkan seragam untuk seluruh Psikolog Profesional Mandiri.
              </p>
            </div>
          </div>
          <span className="inline-flex shrink-0 items-center gap-1.5 rounded-[6px] border border-[#C7D2FE] bg-[#EEF0FF] px-2.5 py-1 text-[11px] font-semibold text-primary">
            <Clock className="size-3" />
            <span>Blok Sesi: 30 Menit (+30m In-Call)</span>
          </span>
        </div>

        {errorMsg && (
          <div
            role="alert"
            className="mt-4 rounded-[8px] border border-crisis-border bg-crisis-bg px-3.5 py-2.5 text-xs font-medium text-crisis-text"
          >
            {errorMsg}
          </div>
        )}

        <div className="mt-4 space-y-4 text-xs">
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="flex flex-col justify-between">
              <label htmlFor="pricing-base" className="mb-1.5 block font-semibold text-ink">
                Tarif Dasar (30 Menit) - Koin
              </label>
              <div>
                <input
                  id="pricing-base"
                  type="number"
                  min={0}
                  step={5}
                  value={priceInput}
                  onChange={(e) => {
                    setPriceInput(e.target.value)
                    if (errorMsg) setErrorMsg(null)
                  }}
                  className="h-10 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-sm font-semibold text-ink focus:border-primary focus:outline-none"
                />
                <p className="mt-1 text-[11px] text-ink-muted">
                  Preview: {formatCoins(parsedPrice)} · ≈ {formatIdr(parsedPrice * safeCoinRateIdr)}
                </p>
              </div>
            </div>

            <div className="flex flex-col justify-between">
              <div className="mb-1.5 flex items-center justify-between gap-2">
                <label htmlFor="pricing-ext" className="font-semibold text-ink">
                  Ekstensi (+30m) - Koin
                </label>
                <button
                  type="button"
                  onClick={() => setExtensionPriceInput(priceInput)}
                  className="shrink-0 cursor-pointer text-[11px] font-semibold text-primary hover:underline"
                >
                  Samakan dasar
                </button>
              </div>
              <div>
                <input
                  id="pricing-ext"
                  type="number"
                  min={0}
                  step={5}
                  value={extensionPriceInput}
                  onChange={(e) => {
                    setExtensionPriceInput(e.target.value)
                    if (errorMsg) setErrorMsg(null)
                  }}
                  className="h-10 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-sm font-semibold text-ink focus:border-primary focus:outline-none"
                />
                <p className="mt-1 text-[11px] text-ink-muted">
                  Preview: {formatCoins(parsedExtensionPrice)} · ≈ {formatIdr(parsedExtensionPrice * safeCoinRateIdr)}
                </p>
              </div>
            </div>
          </div>

          <div className="rounded-[10px] border border-[#E2E8F0] bg-[#F8FAFC] p-3.5">
            <div className="flex items-center justify-between">
              <span className="inline-flex items-center gap-1.5 font-bold text-ink">
                <Percent className="size-3.5 text-primary" />
                Rasio Pembagian Hasil
              </span>
              <span
                className={cn(
                  'rounded-[5px] px-2 py-0.5 text-[10.5px] font-bold',
                  isShareValid
                    ? 'bg-[#DCFCE7] text-[#166534]'
                    : 'bg-[#FEE2E2] text-[#991B1B]',
                )}
              >
                Total: {totalSharePct}%
              </span>
            </div>

            <div className="mt-3 grid gap-3 sm:grid-cols-2">
              <div>
                <label htmlFor="share-counselor" className="mb-1 block font-semibold text-ink">
                  Hak Psikolog Mandiri (%)
                </label>
                <input
                  id="share-counselor"
                  type="number"
                  min={0}
                  max={100}
                  step={0.5}
                  value={counselorShareInput}
                  onChange={(e) => handleCounselorShareChange(e.target.value)}
                  className="h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-sm font-semibold text-ink focus:border-primary focus:outline-none"
                />
              </div>

              <div>
                <label htmlFor="share-platform" className="mb-1 block font-semibold text-ink">
                  Fee Platform EVA (%)
                </label>
                <input
                  id="share-platform"
                  type="number"
                  min={0}
                  max={100}
                  step={0.5}
                  value={platformFeeInput}
                  onChange={(e) => handlePlatformFeeChange(e.target.value)}
                  className="h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-sm font-semibold text-ink focus:border-primary focus:outline-none"
                />
              </div>
            </div>
          </div>

          <div>
            <label htmlFor="pricing-notes" className="mb-1.5 block font-semibold text-ink">
              Catatan Kebijakan / Kesepakatan Tim (Opsional)
            </label>
            <textarea
              id="pricing-notes"
              rows={2}
              value={notesInput}
              onChange={(e) => setNotesInput(e.target.value)}
              placeholder="Misal: Penetapan tarif final rilis v1 berdasarkan hasil review tim."
              className="w-full rounded-[8px] border border-[#CBD5E1] bg-white p-3 text-xs text-ink placeholder:text-ink-muted focus:border-primary focus:outline-none"
            />
          </div>

          <button
            type="submit"
            disabled={saving || !isShareValid}
            className="inline-flex h-10 w-full cursor-pointer items-center justify-center gap-2 rounded-[8px] bg-primary px-4 text-xs font-semibold text-white transition-colors hover:bg-[#464BB8] disabled:cursor-not-allowed disabled:opacity-60"
          >
            {saving ? (
              <>
                <Loader2 className="size-4 animate-spin" />
                <span>Menyimpan Kebijakan…</span>
              </>
            ) : (
              <>
                <Save className="size-4" />
                <span>Simpan &amp; Terapkan Tarif Platform</span>
              </>
            )}
          </button>
        </div>
      </form>

      {/* Kalkulator Preview Estimasi Nominal Transparan */}
      <div className="space-y-4 lg:col-span-6">
        <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-5">
          <div className="flex flex-wrap items-center justify-between gap-2 border-b border-[#E2E8F0] pb-3.5">
            <div className="flex items-center gap-2">
              <span className="flex size-8 items-center justify-center rounded-[8px] bg-emerald-50 text-emerald-700">
                <Calculator className="size-4" />
              </span>
              <div>
                <h2 className="text-sm font-bold text-ink">
                  Kalkulator Simulasi Pembagian Hasil
                </h2>
                <p className="text-[11px] text-ink-muted">
                  Estimasi nominal Koin yang dibayar pasien dan diterima psikolog secara real-time.
                </p>
              </div>
            </div>
            <span className="rounded-[6px] border border-[#CBD5E1] bg-[#F8FAFC] px-2.5 py-1 text-[11px] font-semibold text-ink">
              Kurs aktif: 1 Koin = {formatIdr(safeCoinRateIdr)}
            </span>
          </div>

          <div className="mt-4 grid gap-3 sm:grid-cols-2">
            <div className="rounded-[10px] border border-[#E2E8F0] bg-[#F8FAFC] p-4">
              <span className="inline-flex items-center gap-1 rounded-[5px] border border-[#E2E8F0] bg-white px-2 py-0.5 text-[10px] font-bold text-ink">
                <Clock className="size-3 text-primary" /> Sesi Reguler · 30 Menit
              </span>
              <p className="mt-2.5 text-xl font-bold text-ink">
                {formatCoins(preview30Min.totalPrice)}
              </p>
              <p className="text-[11px] text-ink-muted">
                Dibayar pasien · ≈ {formatIdr(preview30Min.totalPrice * safeCoinRateIdr)}
              </p>

              <div className="mt-3 space-y-2 border-t border-[#E2E8F0] pt-2.5 text-xs">
                <div className="flex items-start justify-between gap-2">
                  <span className="whitespace-nowrap text-ink-soft">
                    Hak Psikolog ({parsedCounselorShare}%)
                  </span>
                  <div className="text-right leading-tight">
                    <p className="font-bold text-emerald-700">
                      {formatCoins(preview30Min.counselorEarning)}
                    </p>
                    <p className="text-[10px] text-ink-muted">
                      ≈ {formatIdr(preview30Min.counselorEarning * safeCoinRateIdr)}
                    </p>
                  </div>
                </div>
                <div className="flex items-start justify-between gap-2">
                  <span className="whitespace-nowrap text-ink-soft">
                    Fee Platform ({parsedPlatformFee}%)
                  </span>
                  <div className="text-right leading-tight">
                    <p className="font-bold text-primary">
                      {formatCoins(preview30Min.platformFee)}
                    </p>
                    <p className="text-[10px] text-ink-muted">
                      ≈ {formatIdr(preview30Min.platformFee * safeCoinRateIdr)}
                    </p>
                  </div>
                </div>
              </div>
            </div>

            <div className="rounded-[10px] border border-[#C7D2FE] bg-[#EEF0FF]/45 p-4">
              <span className="inline-flex items-center gap-1 rounded-[5px] border border-[#C7D2FE] bg-white px-2 py-0.5 text-[10px] font-bold text-primary">
                <CheckCircle2 className="size-3" /> Diperpanjang · 60 Menit
              </span>
              <p className="mt-2.5 text-xl font-bold text-ink">
                {formatCoins(preview60Min.totalPrice)}
              </p>
              <p className="text-[11px] text-ink-muted">
                30m awal + 30m in-call · ≈ {formatIdr(preview60Min.totalPrice * safeCoinRateIdr)}
              </p>

              <div className="mt-3 space-y-2 border-t border-[#C7D2FE] pt-2.5 text-xs">
                <div className="flex items-start justify-between gap-2">
                  <span className="whitespace-nowrap text-ink-soft">
                    Hak Psikolog ({parsedCounselorShare}%)
                  </span>
                  <div className="text-right leading-tight">
                    <p className="font-bold text-emerald-700">
                      {formatCoins(preview60Min.counselorEarning)}
                    </p>
                    <p className="text-[10px] text-ink-muted">
                      ≈ {formatIdr(preview60Min.counselorEarning * safeCoinRateIdr)}
                    </p>
                  </div>
                </div>
                <div className="flex items-start justify-between gap-2">
                  <span className="whitespace-nowrap text-ink-soft">
                    Fee Platform ({parsedPlatformFee}%)
                  </span>
                  <div className="text-right leading-tight">
                    <p className="font-bold text-primary">
                      {formatCoins(preview60Min.platformFee)}
                    </p>
                    <p className="text-[10px] text-ink-muted">
                      ≈ {formatIdr(preview60Min.platformFee * safeCoinRateIdr)}
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

export function AdminPlatformSettingsModule({
  db,
  onFeedback,
}: AdminPlatformSettingsModuleProps) {
  const [searchParams, setSearchParams] = useSearchParams()
  const tabParam = searchParams.get('tab')
  const activeSubTab: SettingsSubTab =
    tabParam === 'coins_catalog' ? 'coins_catalog' : 'pricing'

  const handleSubTabChange = (tab: SettingsSubTab) => {
    setSearchParams((prev) => {
      const next = new URLSearchParams(prev)
      if (tab === 'pricing') {
        next.delete('tab')
      } else {
        next.set('tab', tab)
      }
      next.delete('page')
      return next
    })
  }

  useEffect(() => {
    void fetchActivePlatformPricing().catch(() => undefined)
    void fetchCoinEconomyConfig().catch(() => undefined)
    void fetchCoinPackages().catch(() => undefined)
  }, [])

  const activePackagesCount = db.coinPackages.filter((pkg) => pkg.isActive).length

  return (
    <div>
      <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-center">
        <div>
          <h1 className="text-xl font-bold tracking-[-0.02em] text-ink sm:text-2xl">
            Pengaturan Platform EVA
          </h1>
          <p className="mt-0.5 text-xs text-ink-muted">
            Kelola tarif master telekonsultasi dalam satuan EVA Coin, rasio bagi hasil resmi, kurs dasar koin, serta katalog paket top-up.
          </p>
        </div>

        <div className="inline-flex flex-wrap rounded-[8px] border border-[#E2E8F0] bg-white p-1">
          <button
            type="button"
            onClick={() => handleSubTabChange('pricing')}
            className={cn(
              'cursor-pointer rounded-[6px] px-3 py-1.5 text-xs font-semibold transition-colors',
              activeSubTab === 'pricing'
                ? 'bg-primary text-white'
                : 'text-ink-soft hover:text-ink',
            )}
          >
            Tarif Konsultasi
          </button>
          <button
            type="button"
            onClick={() => handleSubTabChange('coins_catalog')}
            className={cn(
              'cursor-pointer rounded-[6px] px-3 py-1.5 text-xs font-semibold transition-colors',
              activeSubTab === 'coins_catalog'
                ? 'bg-primary text-white'
                : 'text-ink-soft hover:text-ink',
            )}
          >
            Kurs &amp; Paket Koin ({activePackagesCount})
          </button>
        </div>
      </div>

      {activeSubTab === 'coins_catalog' ? (
        <AdminCoinPackagesConfigTab db={db} onFeedback={onFeedback} />
      ) : (
        <PricingSettingsForm
          key={db.pricingConfig.id}
          pricingConfig={db.pricingConfig}
          basePricePerCoinIdr={db.coinEconomyConfig.basePricePerCoinIdr}
          onFeedback={onFeedback}
        />
      )}
    </div>
  )
}
