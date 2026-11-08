import type { HTMLAttributes } from 'react'
import { cn } from '@/lib/cn'

/** Centered max-width wrapper with responsive gutters (Modern Desktop 1440px). */
export function Container({ className, ...rest }: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn('mx-auto w-full max-w-[1440px] px-4 sm:px-6 lg:px-8 xl:px-10', className)}
      {...rest}
    />
  )
}

