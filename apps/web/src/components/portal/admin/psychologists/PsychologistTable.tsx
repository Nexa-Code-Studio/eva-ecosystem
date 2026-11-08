import { Eye, FileCheck2, ShieldCheck, Stethoscope } from 'lucide-react'
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
                <th className="px-5 py-3.5">Psikolog / Relawan</th>
                <th className="px-5 py-3.5">Spesialisasi Klinis</th>
                <th className="px-5 py-3.5">Nomor Legalitas</th>
                <th className="px-5 py-3.5">Kelengkapan Berkas</th>
                <th className="px-5 py-3.5">Status &amp; Antrean</th>
                <th className="px-5 py-3.5 text-right">Aksi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#E2E8F0] text-xs">
              {psychologists.length === 0 ? (
                <tr>
                  <td colSpan={6} className="p-8 text-center text-ink-muted">
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
                  const isMitra = psy.role === 'professional_mitra' || (!psy.role && psy.partnerId)
                  const docCount = psy.documents?.length ?? 0
                  const verifiedDocCount = psy.documents?.filter((d) => d.verified).length ?? 0
                  const hasUpgrade = Boolean(psy.upgradeRequest)

                  return (
                    <tr
                      key={psy.id}
                      className={cn(
                        'cursor-pointer transition-colors',
                        hasUpgrade ? 'bg-amber-50/20 hover:bg-amber-50/40' : 'hover:bg-[#F8FAFC]',
                      )}
                      onClick={() => onSelectPsychologist(psy)}
                    >
                      {/* Column 1: Psikolog, Shield Badge & Domisili */}
                      <td className="max-w-[240px] px-5 py-4">
                        <div className="flex items-center gap-1.5">
                          <span className="truncate font-semibold text-ink" title={psy.fullName}>
                            {psy.fullName}
                          </span>
                          <PsychologistShieldBadge
                            role={psy.role}
                            partnerName={partnerName}
                            upgradeRequest={psy.upgradeRequest}
                          />
                        </div>
                        <div className="mt-0.5 flex items-center gap-1.5 text-[11px] text-ink-muted">
                          <span>{psy.city ?? 'Indonesia'}</span>
                          {isMitra && partnerName && (
                            <>
                              <span>·</span>
                              <span className="truncate font-medium text-emerald-700" title={partnerName}>
                                {partnerName}
                              </span>
                            </>
                          )}
                        </div>
                      </td>

                      {/* Column 2: Spesialisasi Klinis / Fokus */}
                      <td className="px-5 py-4">
                        <div className="flex flex-wrap gap-1 max-w-[220px]">
                          {psy.specializations.slice(0, 2).map((spec) => (
                            <span
                              key={spec}
                              className="inline-flex rounded-[4px] border border-[#E2E8F0] bg-[#F8FAFC] px-1.5 py-0.5 text-[10.5px] font-medium text-ink-muted"
                            >
                              {spec}
                            </span>
                          ))}
                          {psy.specializations.length > 2 && (
                            <span className="inline-flex rounded-[4px] bg-[#F1F5F9] px-1.5 py-0.5 text-[10px] font-semibold text-ink-muted">
                              +{psy.specializations.length - 2}
                            </span>
                          )}
                        </div>
                      </td>

                      {/* Column 3: Legalitas (SIPP & STR) */}
                      <td className="px-5 py-4">
                        <p className="font-mono text-xs font-semibold text-ink">
                          {psy.sippNumber}
                        </p>
                        {psy.strNumber ? (
                          <p className="font-mono text-[11px] text-ink-muted">
                            STR: {psy.strNumber}
                          </p>
                        ) : (
                          <p className="text-[10px] text-ink-muted">
                            {isMitra
                              ? 'STR via Faskes'
                              : psy.role === 'relawan_biasa'
                                ? 'Non-STR (Relawan)'
                                : '-'}
                          </p>
                        )}
                      </td>

                      {/* Column 4: Kelengkapan Berkas */}
                      <td className="px-5 py-4">
                        {isMitra ? (
                          <span className="inline-flex items-center gap-1 text-[11px] font-medium text-emerald-800">
                            <ShieldCheck className="size-3.5 text-emerald-600" /> Valid via Mitra Faskes
                          </span>
                        ) : docCount > 0 ? (
                          <div className="space-y-0.5">
                            <span
                              className={cn(
                                'inline-flex items-center gap-1 rounded-[5px] px-2.5 py-0.5 text-[10px] font-semibold',
                                verifiedDocCount === docCount
                                  ? 'border border-[#BBF7D0] bg-[#F0FDF4] text-[#166534]'
                                  : 'border border-[#FDE68A] bg-[#FEF3C7] text-[#92400E]',
                              )}
                            >
                              <FileCheck2 className="size-3" />
                              {verifiedDocCount}/{docCount} Dokumen Valid
                            </span>
                            {psy.upgradeRequest?.documents && psy.upgradeRequest.documents.length > 0 && (
                              <p className="text-[10px] text-amber-800 font-semibold">
                                + {psy.upgradeRequest.documents.length} Berkas Permohonan
                              </p>
                            )}
                          </div>
                        ) : (
                          <span className="text-[11px] text-ink-muted">Belum ada berkas</span>
                        )}
                      </td>

                      {/* Column 5: Status Verifikasi & Antrean */}
                      <td className="px-5 py-4">
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
                      </td>

                      {/* Column 6: Aksi */}
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
