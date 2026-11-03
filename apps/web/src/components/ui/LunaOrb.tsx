import { cn } from '@/lib/cn'

/**
 * Luna/EVA ambient orb — iridescent conic spectrum with atmospheric halo
 * and 3.2s breathing cycle (signature visual from the mobile app).
 */
export function LunaOrb({ className, still }: { className?: string; still?: boolean }) {
  return (
    <span aria-hidden className={cn('relative inline-block size-24', className)}>
      <span className="absolute -inset-[35%] rounded-full bg-luna-halo blur-md" />
      <span
        className={cn(
          'absolute inset-0 overflow-hidden rounded-full shadow-halo',
          !still && 'animate-breath',
        )}
      >
        <span className={cn('absolute -inset-1/4 bg-luna-orb', !still && 'animate-spin-slow')} />
        <span className="absolute inset-0 rounded-full bg-[radial-gradient(circle_at_32%_28%,rgba(255,255,255,0.95)_0%,rgba(255,255,255,0.35)_28%,transparent_60%)]" />
        <span className="absolute inset-0 rounded-full ring-1 ring-white/60 ring-inset" />
      </span>
    </span>
  )
}

/** Brand icon mark: solid primary squircle with soundwave vitality vector. */
export function LogoMark({ className }: { className?: string }) {
  return (
    <span
      aria-hidden
      className={cn(
        'flex size-8 shrink-0 items-center justify-center rounded-[10px] bg-primary text-white shadow-btn',
        className,
      )}
    >
      <svg
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2.5"
        strokeLinecap="round"
        strokeLinejoin="round"
        className="size-4.5"
      >
        <path d="M3 12h3l2-4 4 8 3-6 2 3h4" />
      </svg>
    </span>
  )
}

/** Brand mark: rotating rainbow orb + wordmark. */
export function Logo({ inverted, className }: { inverted?: boolean; className?: string }) {
  return (
    <span className={cn('inline-flex items-center gap-2.5', className)}>
      <LunaOrb className="size-8" />
      <span
        className={cn(
          'text-[22px] font-extrabold tracking-[-0.02em]',
          inverted ? 'text-white' : 'text-ink',
        )}
      >
        EVA
      </span>
    </span>
  )
}
