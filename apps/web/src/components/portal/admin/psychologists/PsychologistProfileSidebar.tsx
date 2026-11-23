import {
  AlertCircle,
  BookOpen,
  GraduationCap,
  Mail,
  ShieldCheck,
  User,
} from 'lucide-react'
import {
  PracticeStatusBadge,
  PsychologistRoleBadge,
  PsychologistShieldBadge,
  VerificationBadge,
} from '@/components/portal/PortalBadges'
import type { Psychologist } from '@/types/portal'

interface PsychologistProfileSidebarProps {
  psy: Psychologist
}

export function PsychologistProfileSidebar({ psy }: PsychologistProfileSidebarProps) {
  const initials = psy.fullName
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase())
    .join('')

  return (
    <div className="space-y-4 text-xs">
      {psy.verificationNotes && (
        <div className="rounded-[12px] border border-[#FDE68A] bg-[#FEF9EE] p-3.5 text-[#92400E]">
          <div className="flex items-center gap-1.5 font-bold">
            <AlertCircle className="size-4 shrink-0 text-[#D97706]" />
            <span>Catatan Verifikasi Admin:</span>
          </div>
          <p className="mt-1 text-[11px] leading-relaxed">{psy.verificationNotes}</p>
        </div>
      )}

      <div className="rounded-[14px] border border-[#E2E8F0] bg-white p-4 shadow-2xs">
        <div className="flex items-start gap-3.5">
          <div className="flex size-12 shrink-0 items-center justify-center rounded-full bg-primary/10 text-sm font-bold text-primary ring-2 ring-primary/20">
            {initials || <User className="size-5" />}
          </div>
          <div className="min-w-0 flex-1">
            <div className="flex flex-wrap items-center gap-2">
              <h3 className="text-base font-bold text-ink" title={psy.fullName}>
                {psy.fullName}, {psy.titleDegree}
              </h3>
              <PsychologistShieldBadge verificationStatus={psy.verificationStatus} />
            </div>
            <div className="mt-1.5 flex flex-wrap items-center gap-1.5">
              <PsychologistRoleBadge verificationStatus={psy.verificationStatus} />
              <VerificationBadge status={psy.verificationStatus} />
            </div>
          </div>
        </div>

        <div className="mt-3 flex items-center gap-2 border-t border-[#F1F5F9] pt-3 text-[11px] text-ink-soft">
          <Mail className="size-3.5 shrink-0 text-ink-muted" />
          <span className="truncate" title={psy.email}>
            {psy.email}
          </span>
        </div>
      </div>

      <div className="rounded-[14px] border border-[#E2E8F0] bg-white p-3.5 shadow-2xs">
        <div className="flex items-center gap-1.5 border-b border-[#E2E8F0] pb-2">
          <ShieldCheck className="size-3.5 text-primary" />
          <span className="text-[10px] font-bold tracking-wider text-ink-muted uppercase">
            Kredensial Legalitas STR &amp; SIP
          </span>
        </div>

        <div className="mt-2.5 space-y-2 text-[11px]">
          <div className="flex items-center justify-between gap-2">
            <span className="text-ink-muted">Nomor STR:</span>
            <span className="font-mono font-bold text-ink">
              {psy.strNumber ? psy.strNumber : 'Belum dilampirkan'}
            </span>
          </div>

          <div className="flex items-center justify-between gap-2">
            <span className="text-ink-muted">Nomor SIP / SIPP:</span>
            <span className="font-mono font-bold text-ink">
              {psy.sipNumber ?? 'Belum dilampirkan'}
            </span>
          </div>

          <div className="flex items-center justify-between gap-2">
            <span className="shrink-0 text-ink-muted">Organisasi Profesi:</span>
            <span className="truncate font-semibold text-primary" title={psy.association}>
              {psy.association}
            </span>
          </div>

          <div className="flex items-center justify-between gap-2 pt-1">
            <span className="text-ink-muted">Status Praktik App:</span>
            <PracticeStatusBadge status={psy.status} />
          </div>
        </div>
      </div>

      <div className="rounded-[14px] border border-[#E2E8F0] bg-white p-3.5 shadow-2xs">
        <div className="flex items-center gap-1.5 border-b border-[#E2E8F0] pb-2">
          <GraduationCap className="size-3.5 text-indigo-600" />
          <span className="text-[10px] font-bold tracking-wider text-ink-muted uppercase">
            Pendidikan &amp; Pengalaman
          </span>
        </div>

        <div className="mt-2.5 space-y-2 text-[11px]">
          <div>
            <span className="block text-[10px] text-ink-muted">Pendidikan Terakhir</span>
            <p className="mt-0.5 font-semibold text-ink">
              {psy.education || 'S2 Magister Psikologi Profesi (Psikolog Klinis)'}
            </p>
          </div>

          <div className="flex items-center justify-between pt-1">
            <span className="text-ink-muted">Pengalaman Klinis:</span>
            <span className="font-bold text-ink">{psy.yearsOfExperience} Tahun Praktik</span>
          </div>
        </div>
      </div>

      {psy.specializations.length > 0 && (
        <div className="rounded-[14px] border border-[#E2E8F0] bg-white p-3.5 shadow-2xs">
          <div className="flex items-center gap-1.5 border-b border-[#E2E8F0] pb-2">
            <BookOpen className="size-3.5 text-primary" />
            <span className="text-[10px] font-bold tracking-wider text-ink-muted uppercase">
              Fokus Layanan Klinis
            </span>
          </div>
          <div className="mt-2.5 flex flex-wrap gap-1.5">
            {psy.specializations.map((spec) => (
              <span
                key={spec}
                className="rounded-[6px] border border-[#E2E8F0] bg-[#F8FAFC] px-2 py-0.5 text-[10.5px] font-medium text-ink shadow-2xs"
              >
                {spec}
              </span>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
