import { ShieldCheck } from 'lucide-react'
import { cn } from '@/lib/cn'
import type { VerificationStatus } from '@/types/portal'

export interface PsychologistShieldBadgeProps {
  verificationStatus?: VerificationStatus
  size?: 'sm' | 'md'
  className?: string
}

export function PsychologistShieldBadge({
  verificationStatus,
  size = 'md',
  className,
}: PsychologistShieldBadgeProps) {
  if (verificationStatus !== 'verified') return null

  const iconSize = size === 'sm' ? 'size-3' : 'size-3.5'
  const pillSize = size === 'sm' ? 'size-4' : 'size-5'

  return (
    <span
      title="Psikolog Mandiri Terverifikasi (STR & SIP)"
      className={cn(
        'inline-flex shrink-0 items-center justify-center rounded-full bg-indigo-600 text-white shadow-2xs ring-2 ring-white',
        pillSize,
        className,
      )}
    >
      <ShieldCheck className={iconSize} />
    </span>
  )
}

export { PsychologistShieldBadge as PsychologistMedallionBadge }
