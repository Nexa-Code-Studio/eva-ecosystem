import { ArrowUpCircle, Eye, FileCheck2, ShieldCheck, Stethoscope } from 'lucide-react'
import { cn } from '@/lib/cn'
import type { PartnerAccount, Psychologist } from '@/types/portal'
import {
  PsychologistSessionFeeBadge,
  PsychologistShieldBadge,
  UpgradeRequestBadge,
  VerificationBadge,
} from '@/components/portal/PortalBadges'

interface PsychologistCardListProps {
  psychologists: Psychologist[]
  partners: PartnerAccount[]
  onSelectPsychologist: (psy: Psychologist) => void
}

export function PsychologistCardList({
  psychologists,
  partners,
  onSelectPsychologist,
}: PsychologistCardListProps) {
  const getPartnerName = (partnerId: string | null) => {
    if (!partnerId) return null
    return partners.find((p) => p.id === partnerId)?.facilityName ?? null
  }

  if (psychologists.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center rounded-[12px] border border-[#E2E8F0] bg-white p-8 text-center text-ink-muted">
        <Stethoscope className="size-8 text-ink-muted/50" />
        <p className="mt-2 text-xs font-semibold text-ink">Tidak ada data psikolog atau relawan yang cocok</p>
        <p className="text-[11px] text-ink-muted">Ubah kata kunci pencarian atau pilih kategori filter lain.</p>
      </div>
    )
  }

  return (
    <div className="space-y-3">
      {psychologists.map((psy) => {
        const isMitra = psy.role === 'professional_mitra' || (!psy.role && psy.partnerId)
        const partnerName = getPartnerName(psy.partnerId)
        const docCount = psy.documents?.length ?? 0
        const verifiedDocCount = psy.documents?.filter((d) => d.verified).length ?? 0
        const hasUpgrade = Boolean(psy.upgradeRequest)

        return (
          <div
            key={psy.id}
            onClick={() => onSelectPsychologist(psy)}
            className={cn(
              'flex cursor-pointer flex-col justify-between rounded-[12px] border bg-white p-4 shadow-2xs transition-all hover:border-primary/40 active:scale-[0.99]',
              hasUpgrade ? 'border-amber-300 bg-amber-50/15' : 'border-[#E2E8F0]',
            )}
          >
            {/* Card Header: Name with Shield Badge & Domisili */}
            <div className="flex flex-col gap-2 border-b border-[#E2E8F0] pb-3">
              <div className="flex items-start justify-between gap-2">
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-1.5 flex-wrap">
                    <p className="line-clamp-2 text-sm font-bold leading-snug text-ink">{psy.fullName}</p>
                    <PsychologistShieldBadge
                      role={psy.role}
                      partnerName={partnerName}
                      upgradeRequest={psy.upgradeRequest}
                      verificationStatus={psy.verificationStatus}
                    />
                  </div>
                  <p className="mt-0.5 text-xs text-ink-muted">{psy.city ?? 'Indonesia'}</p>
                </div>
                {hasUpgrade && <UpgradeRequestBadge request={psy.upgradeRequest} />}
              </div>
            </div>

            {/* Card Body: SIPP, Partner info & Status */}
            <div className="mt-3 space-y-2 text-xs">
              {psy.specializations.length > 0 && (
                <div className="flex flex-wrap gap-1 pb-1">
                  {psy.specializations.map((spec) => (
                    <span
                      key={spec}
                      className="rounded-[4px] border border-[#E2E8F0] bg-[#F8FAFC] px-1.5 py-0.5 text-[10px] font-medium text-ink-muted"
                    >
                      {spec}
                    </span>
                  ))}
                </div>
              )}

              <div className="flex items-center justify-between">
                <span className="text-ink-muted">Legalitas / SIPP:</span>
                <span className="font-mono font-semibold text-ink">{psy.sippNumber}</span>
              </div>

              {isMitra && partnerName && (
                <div className="flex items-center justify-between">
                  <span className="text-ink-muted">Faskes Mitra:</span>
                  <span className="font-medium text-emerald-700 line-clamp-1 text-right">{partnerName}</span>
                </div>
              )}

              <div className="flex items-center justify-between">
                <span className="text-ink-muted">Tarif &amp; Durasi Sesi:</span>
                <PsychologistSessionFeeBadge
                  feeCoins={psy.sessionFeeCoins}
                  durationMinutes={psy.sessionDurationMinutes}
                />
              </div>

              <div className="flex items-center justify-between">
                <span className="text-ink-muted">Kelengkapan Berkas:</span>
                {isMitra ? (
                  <span className="inline-flex items-center gap-1 text-[11px] font-medium text-emerald-800">
                    <ShieldCheck className="size-3.5 text-emerald-600" /> Valid via Mitra Faskes
                  </span>
                ) : docCount > 0 ? (
                  <span
                    className={cn(
                      'inline-flex items-center gap-1 rounded-[5px] px-2 py-0.5 text-[10px] font-semibold',
                      verifiedDocCount === docCount
                        ? 'border border-[#BBF7D0] bg-[#F0FDF4] text-[#166534]'
                        : 'border border-[#FDE68A] bg-[#FEF3C7] text-[#92400E]',
                    )}
                  >
                    <FileCheck2 className="size-3" />
                    {verifiedDocCount}/{docCount} Valid
                  </span>
                ) : (
                  <span className="text-[11px] text-ink-muted">Belum ada</span>
                )}
              </div>

              <div className="flex items-center justify-between pt-1">
                <span className="text-ink-muted">Status Akun:</span>
                {hasUpgrade ? (
                  <span className="inline-flex items-center gap-1 rounded-[6px] border border-amber-300 bg-amber-100 px-2 py-0.5 text-[11px] font-bold text-amber-900 shadow-2xs">
                    <ArrowUpCircle className="size-3 text-amber-700" />
                    <span>Menunggu Upgrade</span>
                  </span>
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
                    {psy.status === 'active' ? 'Aktif Praktik' : psy.status === 'on_leave' ? 'Sedang Cuti' : 'Nonaktif'}
                  </span>
                )}
              </div>
            </div>

            {/* Card Action Button */}
            <div className="mt-4 pt-3 border-t border-[#E2E8F0]">
              <button
                type="button"
                onClick={(e) => {
                  e.stopPropagation()
                  onSelectPsychologist(psy)
                }}
                className={cn(
                  'flex h-9 w-full cursor-pointer items-center justify-center gap-1.5 rounded-[8px] text-xs font-semibold shadow-2xs transition-colors active:scale-[0.99]',
                  hasUpgrade
                    ? 'bg-amber-600 text-white hover:bg-amber-700'
                    : 'bg-primary text-white hover:bg-primary-hover',
                )}
              >
                <Eye className="size-3.5" />
                <span>{hasUpgrade ? 'Tinjau Permohonan Upgrade' : 'Tinjau Berkas & Detail'}</span>
              </button>
            </div>
          </div>
        )
      })}
    </div>
  )
}
