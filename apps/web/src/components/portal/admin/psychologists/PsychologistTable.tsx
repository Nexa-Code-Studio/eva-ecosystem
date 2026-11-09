import { Clock, Coins, Eye, FileCheck2, ShieldCheck, Stethoscope } from 'lucide-react'
import { cn } from '@/lib/cn'
import type { PartnerAccount, Psychologist } from '@/types/portal'
import {
  PsychologistShieldBadge,
  UpgradeRequestBadge,
  VerificationBadge,
} from '@/components/portal/PortalBadges'
import { PsychologistCardList } from './PsychologistCardList'

interface PsychologistTableProps {
  psychologists: Psychologist[]
  partners: PartnerAccount[]
  onSelectPsychologist: (psy: Psychologist) => void
}

export function PsychologistTable({
  psychologists,
  partners,
  onSelectPsychologist,
}: PsychologistTableProps) {
  const getPartnerName = (partnerId: string | null) => {
    if (!partnerId) return null
    return partners.find((p) => p.id === partnerId)?.facilityName ?? null
  }

  return (
    <div>
      {/* 1. Mobile Card View (< md) */}
      <div className="block md:hidden">
        <PsychologistCardList
          psychologists={psychologists}
          partners={partners}
          onSelectPsychologist={onSelectPsychologist}
        />
      </div>

      {/* 2. Desktop Full-Width Data Table (>= md) */}
      <div className="hidden overflow-hidden rounded-[12px] border border-[#E2E8F0] bg-white md:block">
        <div className="overflow-x-auto">
          <table className="w-full border-collapse text-left">
            <thead>
              <tr className="border-b border-[#E2E8F0] bg-[#F8FAFC] text-[11px] font-bold tracking-wider text-ink-muted uppercase">
                <th className="px-5 py-3.5">Psikolog &amp; Afiliasi</th>
                <th className="px-5 py-3.5">Nomor Legalitas</th>
                <th className="px-5 py-3.5">Layanan &amp; Sesi</th>
                <th className="px-5 py-3.5">Status &amp; Verifikasi</th>
                <th className="px-5 py-3.5 text-right">Aksi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#E2E8F0] text-xs">
              {psychologists.length === 0 ? (
                <tr>
                  <td colSpan={5} className="p-8 text-center text-ink-muted">
                    <div className="flex flex-col items-center justify-center">
                      <Stethoscope className="size-8 text-ink-muted/50" />
                      <p className="mt-2 text-xs font-semibold text-ink">
                        Tidak ada data psikolog atau relawan yang cocok
                      </p>
                      <p className="text-[11px] text-ink-muted">
                        Ubah kata kunci pencarian atau pilih kategori filter lain.
                      </p>
                    </div>
                  </td>
                </tr>
              ) : (
                psychologists.map((psy) => {
                  const partnerName = getPartnerName(psy.partnerId)
                  const isMitra = psy.role === 'relawan_profesional_mitra' || (!psy.role && psy.partnerId)
                  const docCount = psy.documents?.length ?? 0
                  const verifiedDocCount = psy.documents?.filter((d) => d.verified).length ?? 0
                  const hasUpgrade = Boolean(psy.upgradeRequest)
                  const feeCoins = psy.sessionFeeCoins ?? (psy.role === 'relawan_biasa' ? 0 : 100)
                  const durationMinutes = psy.sessionDurationMinutes ?? 45
                  const specPreview = psy.specializations.slice(0, 2).join(' · ')
                  const extraSpecCount = Math.max(0, psy.specializations.length - 2)

                  return (
                    <tr
                      key={psy.id}
                      className={cn(
                        'cursor-pointer transition-colors',
                        hasUpgrade ? 'bg-amber-50/20 hover:bg-amber-50/40' : 'hover:bg-[#F8FAFC]',
                      )}
                      onClick={() => onSelectPsychologist(psy)}
                    >
                      {/* Column 1: Psikolog & Afiliasi */}
                      <td className="max-w-[260px] px-5 py-4">
                        <div className="flex items-center gap-1.5">
                          <span className="truncate font-semibold text-ink" title={psy.fullName}>
                            {psy.fullName}
                          </span>
                          <PsychologistShieldBadge
                            role={psy.role}
                            partnerName={partnerName}
                            upgradeRequest={psy.upgradeRequest}
                            verificationStatus={psy.verificationStatus}
                          />
                        </div>
                        <div className="mt-1 flex items-center gap-1.5 text-[11px] text-ink-muted">
                          <span>{psy.city ?? 'Indonesia'}</span>
                          <span>·</span>
                          {isMitra && partnerName ? (
                            <span className="truncate font-medium text-emerald-700" title={partnerName}>
                              {partnerName}
                            </span>
                          ) : psy.verificationStatus === 'pending' ? (
                            <span className="font-medium text-amber-700">
                              Pendaftaran Baru
                            </span>
                          ) : (
                            <span>
                              {psy.role === 'relawan_biasa' ? 'Relawan Komunitas' : 'Praktik Mandiri'}
                            </span>
                          )}
                        </div>
                      </td>

                      {/* Column 2: Nomor Legalitas (SIPP & STR) */}
                      <td className="px-5 py-4">
                        <p className="font-mono text-xs font-semibold text-ink">
                          {psy.sippNumber}
                        </p>
                        {psy.strNumber ? (
                          <p className="mt-0.5 font-mono text-[11px] text-ink-muted">
                            STR: {psy.strNumber}
                          </p>
                        ) : (
                          <p className="mt-0.5 text-[11px] text-ink-muted">
                            {isMitra
                              ? 'STR via Faskes'
                              : psy.role === 'relawan_biasa'
                                ? 'Non-STR (Relawan)'
                                : '-'}
                          </p>
                        )}
                      </td>

                      {/* Column 3: Layanan & Sesi (Tarif + Spesialisasi Teks Bersih) */}
                      <td className="max-w-[240px] px-5 py-4">
                        <div className="flex items-center gap-1.5 text-xs">
                          <Coins
                            className={cn(
                              'size-3.5 shrink-0',
                              feeCoins === 0 ? 'text-teal-600' : 'text-amber-600',
                            )}
                          />
                          {feeCoins === 0 ? (
                            <span className="font-semibold text-teal-700">Sesi Gratis</span>
                          ) : (
                            <span className="font-semibold text-ink">{feeCoins} Koin</span>
                          )}
                          <span className="text-ink-muted">·</span>
                          <span className="inline-flex items-center gap-1 text-[11px] text-ink-muted">
                            <Clock className="size-3 shrink-0 text-ink-muted/70" />
                            {durationMinutes} menit
                          </span>
                        </div>
                        <p
                          className="mt-1 truncate text-[11px] text-ink-muted"
                          title={psy.specializations.join(', ')}
                        >
                          {specPreview || 'Konseling Umum'}
                          {extraSpecCount > 0 && (
                            <span className="ml-1 font-medium text-ink">
                              (+{extraSpecCount})
                            </span>
                          )}
                        </p>
                      </td>

                      {/* Column 4: Status & Verifikasi (Badge Status + Sub-teks Berkas) */}
                      <td className="px-5 py-4">
                        <div>
                          {hasUpgrade ? (
                            <UpgradeRequestBadge request={psy.upgradeRequest} />
                          ) : !isMitra ? (
                            <VerificationBadge status={psy.verificationStatus ?? 'pending'} />
                          ) : (
                            <span
                              className={cn(
                                'inline-flex rounded-[6px] px-2 py-0.5 text-[11px] font-semibold',
                                psy.status === 'active'
                                  ? 'bg-[#F0FDF4] text-[#166534]'
                                  : psy.status === 'on_leave'
                                    ? 'bg-[#FEF3C7] text-[#92400E]'
                                    : 'bg-[#F1F5F9] text-ink-muted',
                              )}
                            >
                              {psy.status === 'active'
                                ? 'Aktif Praktik'
                                : psy.status === 'on_leave'
                                  ? 'Sedang Cuti'
                                  : 'Nonaktif'}
                            </span>
                          )}
                        </div>
                        <div className="mt-1 flex items-center gap-1 text-[11px] text-ink-muted">
                          {isMitra ? (
                            <>
                              <ShieldCheck className="size-3 shrink-0 text-emerald-600" />
                              <span>Terverifikasi via Mitra</span>
                            </>
                          ) : docCount > 0 ? (
                            <>
                              <FileCheck2
                                className={cn(
                                  'size-3 shrink-0',
                                  verifiedDocCount === docCount
                                    ? 'text-emerald-600'
                                    : 'text-amber-600',
                                )}
                              />
                              <span>
                                {verifiedDocCount}/{docCount} dokumen valid
                              </span>
                              {psy.upgradeRequest?.documents &&
                                psy.upgradeRequest.documents.length > 0 && (
                                  <span className="font-medium text-amber-800">
                                    · +{psy.upgradeRequest.documents.length} berkas upgrade
                                  </span>
                                )}
                            </>
                          ) : (
                            <span>Belum ada berkas</span>
                          )}
                        </div>
                      </td>

                      {/* Column 5: Aksi */}
                      <td className="px-5 py-4 text-right">
                        <button
                          type="button"
                          onClick={(e) => {
                            e.stopPropagation()
                            onSelectPsychologist(psy)
                          }}
                          className={cn(
                            'inline-flex h-8 cursor-pointer items-center gap-1.5 rounded-[6px] border px-3 text-xs font-semibold transition-colors',
                            hasUpgrade
                              ? 'border-amber-400 bg-amber-100 text-amber-900 hover:bg-amber-200'
                              : 'border-primary/30 bg-[#EEF0FF] text-primary hover:bg-primary hover:text-white',
                          )}
                        >
                          <Eye className="size-3.5" />
                          <span>{hasUpgrade ? 'Tinjau Upgrade' : 'Tinjau Berkas'}</span>
                        </button>
                      </td>
                    </tr>
                  )
                })
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
