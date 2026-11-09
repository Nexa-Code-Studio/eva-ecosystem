import {
  ArrowUpCircle,
  Building2,
  CheckCircle2,
  Clock,
  Coins,
  GraduationCap,
  HeartHandshake,
  XCircle,
} from 'lucide-react'
import { cn } from '@/lib/cn'
import type {
  PartnerStatus,
  PsychologistRole,
  PsychologistStatus,
  UpgradeRequest,
  VerificationStatus,
} from '@/types/portal'

export {
  PsychologistShieldBadge,
  PsychologistMedallionBadge,
} from './PsychologistShieldBadge'

export function VerificationBadge({ status }: { status: VerificationStatus }) {
  if (status === 'pending') {
    return (
      <span className="inline-flex shrink-0 items-center gap-1 rounded-[6px] border border-[#FDE68A] bg-[#FEF3C7] px-2 py-0.5 text-[11px] font-semibold text-[#92400E]">
        <Clock className="size-3" /> Menunggu Verifikasi Sertifikat
      </span>
    )
  }
  if (status === 'approved') {
    return (
      <span className="inline-flex shrink-0 items-center gap-1 rounded-[6px] border border-[#BBF7D0] bg-[#F0FDF4] px-2 py-0.5 text-[11px] font-semibold text-[#166534]">
        <CheckCircle2 className="size-3" /> Mandiri Terverifikasi
      </span>
    )
  }
  if (status === 'rejected') {
    return (
      <span className="inline-flex shrink-0 items-center gap-1 rounded-[6px] border border-[#FECACA] bg-[#FEF2F2] px-2 py-0.5 text-[11px] font-semibold text-[#991B1B]">
        <XCircle className="size-3" /> Berkas Ditolak
      </span>
    )
  }
  return (
    <span className="inline-flex shrink-0 items-center gap-1 rounded-[6px] border border-[#CBD5E1] bg-[#F1F5F9] px-2 py-0.5 text-[11px] font-semibold text-ink-soft">
      Nonaktif
    </span>
  )
}

export function PartnerStatusBadge({
  status,
}: {
  status: PartnerStatus
  isResubmitted?: boolean
}) {
  if (status === 'pending') {
    return (
      <span className="inline-flex shrink-0 items-center gap-1 rounded-[6px] border border-[#FDE68A] bg-[#FEF3C7] px-2 py-0.5 text-[11px] font-semibold text-[#92400E]">
        <Clock className="size-3" />
        Menunggu Verifikasi
      </span>
    )
  }
  if (status === 'approved') {
    return (
      <span className="inline-flex shrink-0 items-center gap-1 rounded-[6px] border border-[#BBF7D0] bg-[#F0FDF4] px-2 py-0.5 text-[11px] font-semibold text-[#166534]">
        <CheckCircle2 className="size-3" />
        Disetujui
      </span>
    )
  }
  if (status === 'rejected') {
    return (
      <span className="inline-flex shrink-0 items-center gap-1 rounded-[6px] border border-[#FECACA] bg-[#FEF2F2] px-2 py-0.5 text-[11px] font-semibold text-[#991B1B]">
        <XCircle className="size-3" />
        Ditolak
      </span>
    )
  }
  return (
    <span className="inline-flex shrink-0 items-center gap-1 rounded-[6px] border border-[#CBD5E1] bg-[#F1F5F9] px-2 py-0.5 text-[11px] font-semibold text-ink-soft">
      Dinonaktifkan
    </span>
  )
}

export function PracticeStatusBadge({ status }: { status: PsychologistStatus }) {
  return (
    <span
      className={cn(
        'rounded-[6px] px-2 py-0.5 text-[11px] font-semibold',
        status === 'active'
          ? 'bg-[#F0FDF4] text-[#166534]'
          : status === 'on_leave'
            ? 'bg-[#FEF3C7] text-[#92400E]'
            : 'bg-[#F1F5F9] text-ink-muted',
      )}
    >
      {status === 'active'
        ? 'Aktif Praktik'
        : status === 'on_leave'
          ? 'Sedang Cuti'
          : 'Nonaktif'}
    </span>
  )
}

export function PsychologistRoleBadge({
  role,
  verificationStatus,
  className,
}: {
  role?: PsychologistRole
  verificationStatus?: VerificationStatus
  className?: string
}) {
  if (verificationStatus === 'pending' && role !== 'relawan_profesional_mitra') {
    return null
  }

  if (role === 'relawan_profesional_mitra') {
    return (
      <span
        className={cn(
          'inline-flex shrink-0 items-center gap-1.5 rounded-[6px] border border-emerald-200 bg-emerald-50 px-2 py-0.5 text-[11px] font-bold text-emerald-800 shadow-2xs',
          className,
        )}
      >
        <Building2 className="size-3 text-emerald-600" />
        <span>Relawan Profesional (Mitra)</span>
      </span>
    )
  }

  if (role === 'relawan_profesional_non_mitra') {
    return (
      <span
        className={cn(
          'inline-flex shrink-0 items-center gap-1.5 rounded-[6px] border border-indigo-200 bg-indigo-50 px-2 py-0.5 text-[11px] font-bold text-indigo-800 shadow-2xs',
          className,
        )}
      >
        <GraduationCap className="size-3 text-indigo-600" />
        <span>Relawan Profesional (Non Mitra)</span>
      </span>
    )
  }

  // Default to relawan pendamping
  return (
    <span
      className={cn(
        'inline-flex shrink-0 items-center gap-1.5 rounded-[6px] border border-sky-200 bg-sky-50 px-2 py-0.5 text-[11px] font-bold text-sky-800 shadow-2xs',
        className,
      )}
    >
      <HeartHandshake className="size-3 text-sky-600" />
      <span>Relawan Pendamping</span>
    </span>
  )
}

export function UpgradeRequestBadge({
  request,
  className,
}: {
  request?: UpgradeRequest | null
  className?: string
}) {
  if (!request) return null

  return (
    <span
      className={cn(
        'inline-flex shrink-0 items-center gap-1.5 rounded-[6px] border border-amber-400 bg-amber-100 px-2 py-0.5 text-[10px] font-bold text-amber-900 shadow-xs',
        className,
      )}
    >
      <ArrowUpCircle className="size-3 text-amber-700" />
      <span>Menunggu Upgrade ke Relawan Profesional (Non Mitra)</span>
    </span>
  )
}

export function PsychologistSessionFeeBadge({
  feeCoins,
  durationMinutes,
  className,
}: {
  feeCoins?: number
  durationMinutes?: number
  className?: string
}) {
  const isFree = !feeCoins || feeCoins === 0
  const duration = durationMinutes ?? (isFree ? 30 : 45)

  if (isFree) {
    return (
      <span
        className={cn(
          'inline-flex shrink-0 items-center gap-1 rounded-[6px] border border-[#CBD5E1] bg-[#F8FAFC] px-2 py-0.5 text-[11px] font-semibold text-ink-soft',
          className,
        )}
      >
        <span>Gratis / {duration} mnt</span>
      </span>
    )
  }

  return (
    <span
      className={cn(
        'inline-flex shrink-0 items-center gap-1 rounded-[6px] border border-amber-300 bg-amber-50 px-2 py-0.5 text-[11px] font-bold text-amber-900',
        className,
      )}
    >
      <Coins className="size-3 text-amber-600" />
      <span>
        {feeCoins} Koin / {duration} mnt
      </span>
    </span>
  )
}


