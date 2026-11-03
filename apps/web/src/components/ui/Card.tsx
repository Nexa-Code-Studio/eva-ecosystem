import type { HTMLAttributes } from 'react'
import { cn } from '@/lib/cn'

type CardVariant = 'glass' | 'solid' | 'insight' | 'outline'
type CardPadding = 'none' | 'sm' | 'md' | 'lg'

export interface CardProps extends HTMLAttributes<HTMLDivElement> {
  variant?: CardVariant
  padding?: CardPadding
  /** Adds a lift + glow on hover (for clickable cards). */
  interactive?: boolean
}

const variants: Record<CardVariant, string> = {
  // GlassCard: rgba(255,255,255,.8) + blur(20px) + 1.2px white/40 border + L2 shadow
  glass: 'glass',
  solid: 'bg-surface border-[1.2px] border-divider shadow-subtle',
  insight: 'bg-luna-insight border-[1.2px] border-white/60 shadow-glass',
  outline: 'bg-transparent border-[1.2px] border-border-subtle',
}

const paddings: Record<CardPadding, string> = {
  none: '',
  sm: 'p-4',
  md: 'p-5 sm:p-6',
  lg: 'p-6 sm:p-7',
}

/** Card mirroring the mobile `GlassCard` (24px radius by default). */
export function Card({
  variant = 'glass',
  padding = 'md',
  interactive,
  className,
  ...rest
}: CardProps) {
  return (
    <div
      className={cn(
        'relative rounded-card',
        variants[variant],
        paddings[padding],
        interactive &&
          'transition-[transform,box-shadow,border-color] duration-300 ease-luna hover:-translate-y-1 hover:shadow-nav',
        className,
      )}
      {...rest}
    />
  )
}
