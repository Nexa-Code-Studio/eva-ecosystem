import type { ReactNode } from 'react'
import { cn } from '@/lib/cn'

export type IconTileTone = 'primary' | 'secondary' | 'tertiary' | 'blush' | 'success' | 'crisis' | 'fab'

const tones: Record<IconTileTone, string> = {
  primary: 'bg-primary-container text-primary',
  secondary: 'bg-secondary text-secondary-dark',
  tertiary: 'bg-tertiary/50 text-tertiary-dark',
  blush: 'bg-blush/35 text-[#B4466A]',
  success: 'bg-success/15 text-[#0F7A57]',
  crisis: 'bg-crisis-bg text-crisis-text',
  fab: 'bg-luna-fab text-white shadow-btn',
}

const sizes = {
  sm: 'size-9 rounded-badge [&>svg]:size-[18px]',
  md: 'size-12 rounded-icon [&>svg]:size-[22px]',
  lg: 'size-14 rounded-shortcut [&>svg]:size-6',
}

/** Mini icon container (14px radius on mobile) used in shortcuts & feature cards. */
export function IconTile({
  tone = 'primary',
  size = 'md',
  className,
  children,
}: {
  tone?: IconTileTone
  size?: keyof typeof sizes
  className?: string
  children: ReactNode
}) {
  return (
    <span
      aria-hidden
      className={cn('inline-flex shrink-0 items-center justify-center', tones[tone], sizes[size], className)}
    >
      {children}
    </span>
  )
}
