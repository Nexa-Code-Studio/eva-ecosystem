import type { AnchorHTMLAttributes, ButtonHTMLAttributes, ReactNode } from 'react'
import { Link, type LinkProps } from 'react-router'
import { cn } from '@/lib/cn'

type Variant = 'primary' | 'fab' | 'secondary' | 'outline' | 'social' | 'ghost' | 'light'
type Size = 'sm' | 'md' | 'lg'

const base =
  'group/btn relative inline-flex select-none items-center justify-center gap-2 whitespace-nowrap rounded-pill font-semibold leading-[1.2] ' +
  'transition-[transform,filter,background-color,box-shadow,border-color,color] duration-[250ms] ease-luna ' +
  'active:scale-[0.98] disabled:pointer-events-none disabled:opacity-50'

const variants: Record<Variant, string> = {
  // Primary: #5358CB, crisp white text, L3 glow, hover brightness(1.08)
  primary: 'bg-primary text-white shadow-btn hover:brightness-[1.08] hover:shadow-fab',
  // Signature FAB gradient (#6C63FF -> #5358CB -> #3B3E99) with vivid white text & L5 glow
  fab: 'bg-luna-fab text-white shadow-fab hover:brightness-[1.10] hover:shadow-[0_8px_25px_rgba(83,88,203,0.55)]',
  // Solid White secondary: crisp light background, dark charcoal text, clear outline
  secondary:
    'border-2 border-[#C7D2FE] bg-white text-ink shadow-subtle hover:border-primary hover:text-primary hover:shadow-glass hover:bg-[#F8F9FE]',
  // Outline: 2px primary border, hover rgba(232,233,255,.35)
  outline:
    'border-2 border-primary bg-transparent text-primary hover:bg-[rgba(232,233,255,0.35)]',
  // Social auth: white, 1.5px #E2E8F0 border, charcoal text
  social:
    'border-[1.5px] border-border-subtle bg-surface text-ink hover:border-primary-light/60 hover:shadow-subtle',
  ghost: 'text-ink-soft hover:bg-primary-container/60 hover:text-primary',
  // For dark / gradient backgrounds
  light: 'bg-white text-primary shadow-subtle hover:brightness-[1.03] hover:shadow-glass',
}

const sizes: Record<Size, string> = {
  sm: 'h-10 px-4 text-xs font-semibold',
  md: 'h-[50px] px-6 text-sm font-semibold',
  lg: 'h-[54px] px-8 text-base font-bold tracking-wide', // 54px — mobile CustomPillButton height
}

interface CommonProps {
  variant?: Variant
  size?: Size
  leftIcon?: ReactNode
  rightIcon?: ReactNode
  fullWidth?: boolean
  className?: string
}

type ButtonAsButton = CommonProps & ButtonHTMLAttributes<HTMLButtonElement> & { href?: undefined; to?: undefined }
type ButtonAsLink = CommonProps & AnchorHTMLAttributes<HTMLAnchorElement> & { href: string; to?: undefined }
type ButtonAsRouterLink = CommonProps & Omit<LinkProps, 'size'> & { to: string; href?: undefined }
export type ButtonProps = ButtonAsButton | ButtonAsLink | ButtonAsRouterLink

/**
 * Pill button mirroring the mobile `CustomPillButton`.
 * Renders a `<Link>` when `to` is provided, an `<a>` when `href` is provided, otherwise a `<button>`.
 */
export function Button(props: ButtonProps) {
  const {
    variant = 'primary',
    size = 'md',
    leftIcon,
    rightIcon,
    fullWidth,
    className,
    children,
    ...rest
  } = props

  const classes = cn(base, sizes[size], variants[variant], fullWidth && 'w-full', className)
  const content = (
    <span className="relative z-10 inline-flex items-center justify-center gap-2 text-inherit font-inherit">
      {leftIcon && <span className="shrink-0 [&>svg]:size-[18px] text-inherit">{leftIcon}</span>}
      <span className="text-inherit">{children}</span>
      {rightIcon && (
        <span className="shrink-0 text-inherit transition-transform duration-[250ms] ease-luna group-hover/btn:translate-x-0.5 [&>svg]:size-[18px]">
          {rightIcon}
        </span>
      )}
    </span>
  )

  if ('to' in rest && typeof rest.to === 'string') {
    return (
      <Link className={classes} {...(rest as LinkProps)}>
        {content}
      </Link>
    )
  }

  if (typeof rest.href === 'string') {
    return (
      <a className={classes} {...(rest as AnchorHTMLAttributes<HTMLAnchorElement>)}>
        {content}
      </a>
    )
  }

  const { type = 'button', ...buttonRest } = rest as ButtonHTMLAttributes<HTMLButtonElement>
  return (
    <button type={type} className={classes} {...buttonRest}>
      {content}
    </button>
  )
}
