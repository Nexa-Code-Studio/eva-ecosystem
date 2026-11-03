import type { ReactNode } from 'react'
import { cn } from '@/lib/cn'

export interface PhoneFrameProps {
  /** Path to a real app screenshot. When provided it replaces the placeholder UI. */
  screenshot?: string
  screenshotAlt?: string
  children?: ReactNode
  className?: string
  /** Hide status bar (e.g. when screenshot already contains one). */
  bare?: boolean
}

/**
 * Device frame for showcasing the EVA mobile app.
 * Drop a screenshot via `screenshot="/screens/home.png"` (put files in /public/screens).
 */
export function PhoneFrame({ screenshot, screenshotAlt = '', children, className, bare }: PhoneFrameProps) {
  return (
    <div
      className={cn(
        'relative aspect-[9/19.2] w-[290px] rounded-[48px] bg-obsidian p-[10px] sm:w-[320px] lg:w-[350px] xl:w-[370px]',
        'shadow-[0_40px_80px_-20px_rgba(59,62,153,0.45),0_0_0_1.5px_rgba(255,255,255,0.08)_inset]',
        className,
      )}
    >
      {/* side buttons */}
      <span aria-hidden className="absolute top-28 -left-[3px] h-12 w-[3px] rounded-l bg-obsidian" />
      <span aria-hidden className="absolute top-44 -left-[3px] h-12 w-[3px] rounded-l bg-obsidian" />
      <span aria-hidden className="absolute top-36 -right-[3px] h-16 w-[3px] rounded-r bg-obsidian" />

      <div className="relative h-full w-full overflow-hidden rounded-[37px] bg-luna-screen">
        {/* dynamic island */}
        <span
          aria-hidden
          className="absolute top-2.5 left-1/2 z-30 h-[26px] w-[92px] -translate-x-1/2 rounded-pill bg-obsidian"
        />
        {screenshot ? (
          <img
            src={screenshot}
            alt={screenshotAlt}
            className="h-full w-full object-cover"
            loading="lazy"
            decoding="async"
          />
        ) : (
          <div className="flex h-full flex-col">
            {!bare && <StatusBar />}
            <div className="relative min-h-0 flex-1">{children}</div>
          </div>
        )}
      </div>
    </div>
  )
}

function StatusBar() {
  return (
    <div className="flex h-11 shrink-0 items-end justify-between px-7 pb-1 text-[11px] font-semibold text-ink">
      <span>21:24</span>
      <span className="flex items-center gap-1" aria-hidden>
        <span className="flex items-end gap-[2px]">
          {[4, 6, 8, 10].map((h) => (
            <span key={h} className="w-[3px] rounded-sm bg-ink" style={{ height: h }} />
          ))}
        </span>
        <span className="ml-1 h-[10px] w-[20px] rounded-[3px] border border-ink/70 p-[1.5px]">
          <span className="block h-full w-3/4 rounded-[1px] bg-ink" />
        </span>
      </span>
    </div>
  )
}
