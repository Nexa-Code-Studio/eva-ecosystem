import { Eye, FileCheck2, Stethoscope } from 'lucide-react'
import {
  PsychologistShieldBadge,
  VerificationBadge,
} from '@/components/portal/PortalBadges'
import { cn } from '@/lib/cn'
import type { Psychologist } from '@/types/portal'

interface PsychologistCardListProps {
  psychologists: Psychologist[]
  onSelectPsychologist: (psy: Psychologist) => void
}

export function PsychologistCardList({
  psychologists,
  onSelectPsychologist,
}: PsychologistCardListProps) {
  if (psychologists.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center rounded-[12px] border border-[#E2E8F0] bg-white p-8 text-center text-ink-muted">
        <Stethoscope className="size-8 text-ink-muted/50" />
        <p className="mt-2 text-xs font-semibold text-ink">Tidak ada data psikolog yang sesuai</p>
        <p className="text-[11px] text-ink-muted">
          Ubah kata kunci pencarian atau pilih tab status verifikasi lain.
        </p>
      </div>
    )
  }

  return (
    <div className="space-y-3">
      {psychologists.map((psy) => {
        const docCount = psy.documents?.length ?? 0
        const verifiedDocCount = psy.documents?.filter((d) => d.verified).length ?? 0

        return (
          <div
            key={psy.id}
            onClick={() => onSelectPsychologist(psy)}
            className="flex cursor-pointer flex-col justify-between rounded-[12px] border border-[#E2E8F0] bg-white p-4 shadow-2xs transition-all hover:border-primary/40"
          >
            <div className="flex items-start justify-between gap-2 border-b border-[#E2E8F0] pb-3">
              <div className="min-w-0 flex-1">
                <div className="flex flex-wrap items-center gap-1.5">
                  <p className="text-sm font-bold leading-snug text-ink">
                    {psy.fullName}, {psy.titleDegree}
                  </p>
                  <PsychologistShieldBadge verificationStatus={psy.verificationStatus} />
                </div>
                <p className="mt-0.5 truncate text-xs text-ink-muted">
                  {psy.email} · {psy.yearsOfExperience} thn pengalaman
                </p>
              </div>
              <VerificationBadge status={psy.verificationStatus} />
            </div>

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

              <div className="flex items-center justify-between gap-2">
                <span className="text-ink-muted">STR:</span>
                <span className="font-mono font-semibold text-ink">
                  {psy.strNumber || 'Belum dilampirkan'}
                </span>
              </div>

              <div className="flex items-center justify-between gap-2">
                <span className="text-ink-muted">SIP / SIPP:</span>
                <span className="font-mono text-ink-soft">
                  {psy.sipNumber ?? 'Belum dilampirkan'}
                </span>
              </div>

              <div className="flex items-center justify-between gap-2">
                <span className="text-ink-muted">Kelengkapan Berkas:</span>
                {docCount > 0 ? (
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
            </div>

            <div className="mt-4 border-t border-[#E2E8F0] pt-3">
              <button
                type="button"
                onClick={(e) => {
                  e.stopPropagation()
                  onSelectPsychologist(psy)
                }}
                className="flex h-9 w-full cursor-pointer items-center justify-center gap-1.5 rounded-[8px] bg-primary text-xs font-semibold text-white shadow-2xs transition-colors hover:bg-primary-hover"
              >
                <Eye className="size-3.5" />
                <span>Tinjau Berkas STR/SIP</span>
              </button>
            </div>
          </div>
        )
      })}
    </div>
  )
}
