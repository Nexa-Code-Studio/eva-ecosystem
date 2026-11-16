import { cn } from '@/lib/cn'

/**
 * Luna/EVA ambient orb: iridescent conic spectrum with atmospheric halo
 * and 3.2s breathing cycle (signature visual from the mobile app).
 */
export function LunaOrb({
  className,
  still,
  speaking = false,
}: {
  className?: string
  still?: boolean
  speaking?: boolean
}) {
  return (
    <span
      aria-hidden
      className={cn(
        'relative inline-block size-24 transition-transform duration-500 ease-luna motion-reduce:transition-none',
        speaking && 'scale-[1.12] motion-reduce:scale-100',
        className,
      )}
    >
      {speaking && !still && (
        <>
          <span className="pointer-events-none absolute -inset-3 rounded-full border-2 border-primary-light/55 animate-[ping_2.1s_cubic-bezier(0,0,0.2,1)_infinite] motion-reduce:hidden" />
          <span
            className="pointer-events-none absolute -inset-5 rounded-full border border-primary/35 animate-[ping_2.1s_cubic-bezier(0,0,0.2,1)_infinite] motion-reduce:hidden"
            style={{ animationDelay: '700ms' }}
          />
        </>
      )}
      <span
        className={cn(
          'absolute -inset-[35%] rounded-full bg-luna-halo blur-md transition-[opacity,transform] duration-500',
          speaking ? 'scale-110 opacity-100' : 'opacity-85',
        )}
      />
      <span
        className={cn(
          'absolute inset-0 overflow-hidden rounded-full shadow-halo transition-shadow duration-500',
          !still && 'animate-breath',
          speaking && 'ring-2 ring-primary-light/70',
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
      width={500}
      height={500}
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
