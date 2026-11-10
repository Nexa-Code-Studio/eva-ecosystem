import { cn } from '@/lib/cn'

/**
 * Luna/EVA ambient orb: iridescent conic spectrum with atmospheric halo
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

/** Brand icon mark: official EVA mobile brand logo icon. */
export function LogoMark({ className }: { className?: string }) {
  return (
    <img
      src="/eva_logo.png"
      alt="EVA Logo"
      className={cn('size-8 shrink-0 object-contain', className)}
    />
  )
}

/** Brand mark: official EVA mobile brand logo + wordmark. */
export function Logo({
  inverted,
  className,
  iconClassName,
}: {
  inverted?: boolean
  className?: string
  iconClassName?: string
}) {
  return (
    <span className={cn('inline-flex items-center gap-2.5', className)}>
      <img
        src="/eva_logo.png"
        alt="EVA Logo"
        className={cn('size-8 shrink-0 object-contain', iconClassName)}
      />
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
