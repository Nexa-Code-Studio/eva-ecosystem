import { Eye, FileCheck2, Stethoscope } from 'lucide-react'
import {
  PsychologistShieldBadge,
  VerificationBadge,
} from '@/components/portal/PortalBadges'
import type { Psychologist } from '@/types/portal'
import { PsychologistCardList } from './PsychologistCardList'

interface PsychologistTableProps {
  psychologists: Psychologist[]
  onSelectPsychologist: (psy: Psychologist) => void
}

export function PsychologistTable({
  psychologists,
  onSelectPsychologist,
}: PsychologistTableProps) {
  return (
    <div>
      {/* 1. Mobile Card View (< md) */}
      <div className="block md:hidden">
        <PsychologistCardList
          psychologists={psychologists}
          onSelectPsychologist={onSelectPsychologist}
        />
      </div>

      {/* 2. Desktop Full-Width Data Table (>= md) */}
      <div className="hidden overflow-hidden rounded-[12px] border border-[#E2E8F0] bg-white md:block">
        <div className="overflow-x-auto">
          <table className="w-full border-collapse text-left">
            <thead>
              <tr className="border-b border-[#E2E8F0] bg-[#F8FAFC] text-[11px] font-bold tracking-wider text-ink-muted uppercase">
                <th className="px-5 py-3.5">Psikolog Mandiri</th>
                <th className="px-5 py-3.5">Nomor STR &amp; SIP</th>
                <th className="px-5 py-3.5">Asosiasi &amp; Spesialisasi</th>
                <th className="px-5 py-3.5">Status Verifikasi</th>
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
                        Tidak ada data psikolog yang sesuai
                      </p>
                      <p className="text-[11px] text-ink-muted">
                        Ubah kata kunci pencarian atau pilih tab status verifikasi lain.
                      </p>
                    </div>
                  </td>
                </tr>
              ) : (
                psychologists.map((psy) => {
                  const docCount = psy.documents?.length ?? 0
                  const verifiedDocCount = psy.documents?.filter((d) => d.verified).length ?? 0
                  const specPreview = psy.specializations.slice(0, 2).join(' · ')
                  const extraSpecCount = Math.max(0, psy.specializations.length - 2)

                  return (
                    <tr
                      key={psy.id}
                      onClick={() => onSelectPsychologist(psy)}
                      className="cursor-pointer transition-colors hover:bg-[#F8FAFC]"
                    >
                      <td className="max-w-[260px] px-5 py-4">
                        <div className="flex items-center gap-1.5">
                          <span className="truncate font-semibold text-ink" title={psy.fullName}>
                            {psy.fullName}, {psy.titleDegree}
                          </span>
                          <PsychologistShieldBadge verificationStatus={psy.verificationStatus} />
                        </div>
                        <div className="mt-1 flex items-center gap-1.5 text-[11px] text-ink-muted">
                          <span>{psy.city ?? 'Indonesia'}</span>
                          <span>·</span>
                          <span>{psy.yearsOfExperience} thn pengalaman</span>
                        </div>
                      </td>

                      <td className="px-5 py-4">
                        <p className="font-mono text-xs font-semibold text-ink">
                          STR: {psy.strNumber}
                        </p>
                        <p className="mt-0.5 font-mono text-[11px] text-ink-muted">
                          {psy.sipNumber ? `SIP: ${psy.sipNumber}` : 'SIP: Belum dilampirkan'}
                        </p>
                      </td>

                      <td className="max-w-[260px] px-5 py-4">
                        <p className="truncate font-medium text-ink" title={psy.association}>
                          {psy.association}
                        </p>
                        <p
                          className="mt-1 truncate text-[11px] text-ink-muted"
                          title={psy.specializations.join(', ')}
                        >
                          {specPreview || 'Konseling Psikologi'}
                          {extraSpecCount > 0 && (
                            <span className="ml-1 font-medium text-ink">
                              (+{extraSpecCount})
                            </span>
                          )}
                        </p>
                      </td>

                      <td className="px-5 py-4">
                        <VerificationBadge status={psy.verificationStatus} />
                        <div className="mt-1 flex items-center gap-1 text-[11px] text-ink-muted">
                          {docCount > 0 ? (
                            <>
                              <FileCheck2
                                className={
                                  verifiedDocCount === docCount
                                    ? 'size-3 shrink-0 text-emerald-600'
                                    : 'size-3 shrink-0 text-amber-600'
                                }
                              />
                              <span>
                                {verifiedDocCount}/{docCount} berkas diperiksa
                              </span>
                            </>
                          ) : (
                            <span>Belum ada lampiran digital</span>
                          )}
                        </div>
                      </td>

                      <td className="px-5 py-4 text-right">
                        <button
                          type="button"
                          onClick={(e) => {
                            e.stopPropagation()
                            onSelectPsychologist(psy)
                          }}
                          className="inline-flex h-8 cursor-pointer items-center gap-1.5 rounded-[6px] border border-primary/30 bg-[#EEF0FF] px-3 text-xs font-semibold text-primary transition-colors hover:bg-primary hover:text-white"
                        >
                          <Eye className="size-3.5" />
                          <span>Tinjau Berkas</span>
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
