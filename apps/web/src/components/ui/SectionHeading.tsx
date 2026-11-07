import type { ReactNode } from 'react'
import { cn } from '@/lib/cn'

export interface SectionHeadingProps {
  kicker?: string
  kickerIcon?: ReactNode
  title: ReactNode
  description?: ReactNode
  align?: 'center' | 'left'
  /** Use on dark backgrounds. */
  inverted?: boolean
  className?: string
  id?: string
}

/** Overline kicker + section title + supporting copy. */
export function SectionHeading({
  kicker,
  title,
  description,
  align = 'center',
  inverted,
  className,
  id,
}: SectionHeadingProps) {
  return (
    <div
      className={cn(
        'reveal flex max-w-4xl xl:max-w-5xl flex-col gap-3',
        align === 'center' ? 'mx-auto items-center text-center' : 'items-start text-left',
        className,
      )}
    >
      {kicker && (
        <span
          className={cn(
            'text-overline font-bold tracking-[0.14em] uppercase',
            inverted ? 'text-primary-light' : 'text-primary',
          )}
        >
          {kicker}
        </span>
      )}
      <h2 id={id} className={cn('text-section', inverted && 'text-white')}>
        {title}
      </h2>
      {description && (
        <p className={cn('text-body-lg sm:text-[17px]', inverted ? 'text-white/70' : 'text-ink-soft')}>
          {description}
        </p>
      )}
    </div>
  )
}
