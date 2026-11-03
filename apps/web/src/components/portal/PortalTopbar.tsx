import { CheckCircle2, LogOut } from 'lucide-react'
import type { ReactNode } from 'react'
import { Link } from 'react-router'
import { LunaOrb } from '@/components/ui'
import { cn } from '@/lib/cn'

interface PortalTopbarProps {
  badgeLabel: ReactNode
  title: string
  subtitle: string
  onLogout: () => void
  maxWidthClass?: string
  extraActions?: ReactNode
}

export function PortalTopbar({
  badgeLabel,
  title,
  subtitle,
  onLogout,
  maxWidthClass = 'max-w-7xl',
  extraActions,
}: PortalTopbarProps) {
  return (
    <header className="sticky top-0 z-30 border-b border-[#E2E8F0] bg-white">
      <div
        className={cn(
          'mx-auto flex h-16 items-center justify-between px-4 sm:px-6 lg:px-8',
          maxWidthClass,
        )}
      >
        <div className="flex items-center gap-3">
          <Link to="/" className="inline-flex items-center gap-2.5">
            <LunaOrb className="size-8" />
            <span className="text-lg font-bold tracking-[-0.02em] text-ink">EVA</span>
          </Link>
          <span className="h-4 w-[1px] bg-[#CBD5E1]" />
          <span className="inline-flex items-center gap-1.5 rounded-[6px] border border-[#E2E8F0] bg-[#F8FAFC] px-2.5 py-1 text-xs font-semibold text-ink">
            {badgeLabel}
          </span>
        </div>

        <div className="flex items-center gap-3">
          {extraActions}
          <div className="hidden text-right sm:block">
            <p className="text-xs font-semibold text-ink">{title}</p>
            <p className="text-[11px] text-ink-muted">{subtitle}</p>
          </div>
          <button
            type="button"
            onClick={onLogout}
            className="inline-flex h-9 cursor-pointer items-center gap-1.5 rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-xs font-semibold text-ink transition-colors hover:bg-[#F8FAFC]"
          >
            <LogOut className="size-3.5 text-ink-muted" />
            <span>Keluar</span>
          </button>
        </div>
      </div>
    </header>
  )
}

export function PortalFeedbackBanner({
  message,
  onClose,
  variant = 'green',
}: {
  message: string | null
  onClose: () => void
  variant?: 'green' | 'primary'
}) {
  if (!message) return null
  return (
    <div
      role="status"
      className={cn(
        'mt-5 flex items-center justify-between gap-3 rounded-[10px] border px-4 py-3 text-xs font-medium',
        variant === 'green'
          ? 'border-[#BBF7D0] bg-[#F0FDF4] text-[#166534]'
          : 'border-primary/25 bg-primary-container/50 text-ink',
      )}
    >
      <div className="flex items-center gap-2">
        <CheckCircle2
          className={cn(
            'size-4 shrink-0',
            variant === 'green' ? 'text-[#16A34A]' : 'text-primary',
          )}
        />
        <span>{message}</span>
      </div>
      <button
        type="button"
        onClick={onClose}
        className="cursor-pointer text-[11px] font-semibold underline"
      >
        Tutup
      </button>
    </div>
  )
}

