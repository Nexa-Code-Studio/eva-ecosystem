import {
  CheckCircle2,
  Clock,
  ShieldAlert,
  Sparkles,
  Stethoscope,
  XCircle,
} from 'lucide-react'
import { cn } from '@/lib/cn'
import type { PsychologistStatus, VerificationStatus } from '@/types/portal'

export {
  PsychologistShieldBadge,
  PsychologistMedallionBadge,
} from './PsychologistShieldBadge'

export function VerificationBadge({ status }: { status: VerificationStatus }) {
  if (status === 'pending') {
    return (
      <span className="inline-flex shrink-0 items-center gap-1 rounded-[6px] border border-[#FDE68A] bg-[#FEF3C7] px-2 py-0.5 text-[11px] font-semibold text-[#92400E]">
        <Clock className="size-3" /> Menunggu Verifikasi
      </span>
    )
  }
  if (status === 'verified') {
    return (
      <span className="inline-flex shrink-0 items-center gap-1 rounded-[6px] border border-[#BBF7D0] bg-[#F0FDF4] px-2 py-0.5 text-[11px] font-semibold text-[#166534]">
        <CheckCircle2 className="size-3" /> Terverifikasi
      </span>
    )
  }
  if (status === 'rejected') {
    return (
      <span className="inline-flex shrink-0 items-center gap-1 rounded-[6px] border border-[#FECACA] bg-[#FEF2F2] px-2 py-0.5 text-[11px] font-semibold text-[#991B1B]">
        <XCircle className="size-3" /> Ditolak
      </span>
    )
  }
  return (
    <span className="inline-flex shrink-0 items-center gap-1 rounded-[6px] border border-[#CBD5E1] bg-[#F1F5F9] px-2 py-0.5 text-[11px] font-semibold text-ink-soft">
      <ShieldAlert className="size-3" /> Dinonaktifkan
    </span>
  )
}

export function PracticeStatusBadge({ status }: { status: PsychologistStatus }) {
  return (
    <span
      className={cn(
        'inline-flex shrink-0 items-center gap-1 rounded-[6px] px-2 py-0.5 text-[11px] font-semibold',
        status === 'active'
          ? 'bg-[#F0FDF4] text-[#166534]'
          : status === 'on_leave'
            ? 'bg-[#FEF3C7] text-[#92400E]'
            : 'bg-[#F1F5F9] text-ink-muted',
      )}
    >
      {status === 'active'
        ? 'Online / Siap Sesi'
        : status === 'on_leave'
          ? 'Sedang Istirahat'
          : 'Sedang Tidak Aktif'}
    </span>
  )
}

export function PsychologistRoleBadge({
  verificationStatus,
  className,
}: {
  verificationStatus?: VerificationStatus
  className?: string
}) {
  return (
    <span
      className={cn(
        'inline-flex shrink-0 items-center gap-1.5 rounded-[6px] border border-indigo-200 bg-indigo-50 px-2 py-0.5 text-[11px] font-bold text-indigo-800 shadow-2xs',
        className,
      )}
    >
      <Stethoscope className="size-3 text-indigo-600" />
      <span>
        {verificationStatus === 'verified'
          ? 'Psikolog Mandiri Terverifikasi'
          : 'Psikolog Profesional Individu'}
      </span>
    </span>
  )
}

export function SessionDurationBadge({
  durationMinutes,
  isExtended,
  className,
}: {
  durationMinutes: 30 | 60
  isExtended: boolean
  className?: string
}) {
  if (isExtended || durationMinutes === 60) {
    return (
      <span
        className={cn(
          'inline-flex shrink-0 items-center gap-1 rounded-[6px] border border-[#C7D2FE] bg-[#EEF0FF] px-2 py-0.5 text-[11px] font-bold text-primary',
          className,
        )}
      >
        <Sparkles className="size-3" />
        <span>Diperpanjang: 60 Menit</span>
      </span>
    )
  }

  return (
    <span
      className={cn(
        'inline-flex shrink-0 items-center gap-1 rounded-[6px] border border-[#E2E8F0] bg-[#F8FAFC] px-2 py-0.5 text-[11px] font-semibold text-ink',
        className,
      )}
    >
      <Clock className="size-3 text-ink-muted" />
      <span>30 Menit</span>
    </span>
  )
}
