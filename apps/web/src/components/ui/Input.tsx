import type { InputHTMLAttributes, ReactNode, Ref } from 'react'
import { cn } from '@/lib/cn'

export interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  leftIcon?: ReactNode
  rightSlot?: ReactNode
  containerClassName?: string
  invalid?: boolean
  ref?: Ref<HTMLInputElement>
}

/**
 * Pill text field mirroring mobile `CustomPillTextField`:
 * white capsule, 1.2px #E2E8F0 border, 20px/16px padding, 20px slate icons,
 * focus → primary border + 3px soft ring.
 */
export function Input({
  leftIcon,
  rightSlot,
  containerClassName,
  invalid,
  className,
  ref,
  ...rest
}: InputProps) {
  return (
    <div
      className={cn(
        'group/input flex h-[54px] w-full items-center gap-3 rounded-pill border-[1.2px] border-border-subtle bg-surface px-5',
        'transition-[border-color,box-shadow] duration-[250ms] ease-luna',
        'focus-within:border-primary focus-within:shadow-[0_0_0_3px_rgba(83,88,203,0.15)]',
        invalid &&
          'border-error focus-within:border-error focus-within:shadow-[0_0_0_3px_rgba(186,26,26,0.12)]',
        containerClassName,
      )}
    >
      {leftIcon && (
        <span className="shrink-0 text-ink-soft transition-colors group-focus-within/input:text-primary [&>svg]:size-5">
          {leftIcon}
        </span>
      )}
      <input
        ref={ref}
        aria-invalid={invalid || undefined}
        className={cn(
          'h-full min-w-0 flex-1 bg-transparent text-body-lg text-ink outline-none placeholder:text-ink-muted',
          className,
        )}
        {...rest}
      />
      {rightSlot}
    </div>
  )
}
