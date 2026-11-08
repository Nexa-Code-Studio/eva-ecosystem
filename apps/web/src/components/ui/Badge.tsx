import type { HTMLAttributes, ReactNode } from 'react'
import { cn } from '@/lib/cn'

type Tone = 'primary' | 'secondary' | 'tertiary' | 'success' | 'crisis' | 'glass' | 'dark'

export interface BadgeProps extends HTMLAttributes<HTMLSpanElement> {
  tone?: Tone
  icon?: ReactNode
  /** `overline` = uppercase ExtraBold kicker; `label` = caption-style chip. */
  kind?: 'overline' | 'label'
  dot?: boolean
}

const tones: Record<Tone, string> = {
  primary: 'bg-primary-container text-primary',
  secondary: 'bg-secondary text-secondary-dark',
  tertiary: 'bg-tertiary/45 text-tertiary-dark',
  success: 'bg-success/12 text-success',
  crisis: 'bg-crisis-bg text-crisis-text border border-crisis-border',
  glass: 'glass text-primary !shadow-subtle',
  dark: 'bg-white/10 text-white border border-white/15',
}

/** Category badge / overline tag (8–14px radius family on mobile; pill on web for kickers). */
export function Badge({
  tone = 'primary',
  kind = 'label',
  icon,
  dot,
  className,
  children,
  ...rest
}: BadgeProps) {
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1.5 whitespace-nowrap',
        kind === 'overline'
          ? 'rounded-pill px-3.5 py-1.5 text-overline uppercase'
          : 'rounded-badge px-2.5 py-1 text-caption',
        tones[tone],
        className,
      )}
      {...rest}
    >
      {dot && (
        <span className="relative flex size-1.5">
          <span className="absolute inline-flex size-full animate-ping rounded-full bg-current opacity-60" />
          <span className="relative inline-flex size-1.5 rounded-full bg-current" />
        </span>
      )}
      {icon && <span className="shrink-0 [&>svg]:size-3.5">{icon}</span>}
      {children}
    </span>
  )
}
