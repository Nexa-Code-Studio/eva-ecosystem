import { BookOpen, Home, MessageCircle, Mic, User } from 'lucide-react'
import type { CSSProperties } from 'react'
import { cn } from '@/lib/cn'

export const glassMini = 'glass rounded-[18px]'

export function ScreenHeader({ title, subtitle }: { title: string; subtitle?: string }) {
  return (
    <div className="px-5 pt-3">
      {subtitle && (
        <p className="text-[10px] font-extrabold tracking-[0.12em] text-primary uppercase">
          {subtitle}
        </p>
      )}
      <p className="mt-0.5 text-[17px] font-bold text-ink">{title}</p>
    </div>
  )
}

export function FloatingNav({ active = 0 }: { active?: number }) {
  const items = [Home, MessageCircle, null, BookOpen, User]
  return (
    <div className="absolute inset-x-3 bottom-3 flex h-[54px] items-center justify-around rounded-pill border border-white/80 bg-white/95 shadow-nav">
      {items.map((Icon, i) =>
        Icon ? (
          <span
            key={i}
            className={cn(
              'flex h-9 w-11 items-center justify-center rounded-[14px] transition-colors',
              i === active ? 'bg-primary-container text-primary' : 'text-ink-muted',
            )}
          >
            <Icon className="size-[18px]" strokeWidth={i === active ? 2.4 : 1.8} />
          </span>
        ) : (
          <span
            key={i}
            className="-mt-6 flex size-[46px] items-center justify-center rounded-full border-[3px] border-white bg-luna-fab text-white shadow-fab"
          >
            <Mic className="size-5" />
          </span>
        ),
      )}
    </div>
  )
}

export function Waveform({
  bars = 28,
  active = true,
  prominent = false,
  className,
}: {
  bars?: number
  active?: boolean
  prominent?: boolean
  className?: string
}) {
  return (
    <div
      className={cn(
        'flex h-10 items-center justify-center',
        prominent ? 'gap-[3.5px]' : 'gap-[3px]',
        className,
      )}
      aria-hidden
    >
      {Array.from({ length: bars }).map((_, i) => {
        const h = 30 + Math.abs(Math.sin(i * 1.7)) * 70
        return (
          <span
            key={i}
            className={cn(
              'origin-center rounded-full bg-linear-to-t from-primary to-primary-light transition-[transform,opacity] duration-300',
              prominent && active ? 'w-[3.5px]' : 'w-[3px]',
              active ? 'animate-wave opacity-100' : 'scale-y-[0.38] opacity-55',
            )}
            style={
              {
                height: `${h}%`,
                animationDelay: active ? `${(i % 7) * 110}ms` : undefined,
              } as CSSProperties
            }
          />
        )
      })}
    </div>
  )
}

