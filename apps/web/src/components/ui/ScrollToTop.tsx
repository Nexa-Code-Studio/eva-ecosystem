import { ArrowUp } from 'lucide-react'
import { scrollToCenteredSection, useScrolled, useScrollProgress } from '@/hooks/useScroll'
import { cn } from '@/lib/cn'

const RADIUS = 20
const CIRCUMFERENCE = 2 * Math.PI * RADIUS

/**
 * Floating Back-to-Top button with radial SVG scroll progress indicator.
 * Appears after scrolling past 300px, inspired by ekyamuhammad.com.
 */
export function ScrollToTop() {
  const visible = useScrolled(300)
  const progress = useScrollProgress()

  const strokeDashoffset = CIRCUMFERENCE * (1 - progress)

  const handleClick = () => {
    scrollToCenteredSection('top')
  }

  return (
    <button
      type="button"
      onClick={handleClick}
      data-cursor="ATAS"
      aria-label="Kembali ke atas halaman"
      tabIndex={visible ? 0 : -1}
      className={cn(
        'group fixed right-5 bottom-5 z-40 flex size-12 items-center justify-center rounded-full bg-white/95 text-primary shadow-nav backdrop-blur-md transition-[opacity,transform,box-shadow] duration-300 ease-luna hover:-translate-y-0.5 hover:shadow-fab',
        visible ? 'translate-y-0 opacity-100' : 'pointer-events-none translate-y-4 opacity-0',
      )}
    >
      <svg
        aria-hidden="true"
        viewBox="0 0 48 48"
        className="pointer-events-none absolute inset-0 size-full -rotate-90"
      >
        <circle
          cx="24"
          cy="24"
          r={RADIUS}
          fill="none"
          stroke="rgba(83, 88, 203, 0.14)"
          strokeWidth="2.5"
        />
        <circle
          cx="24"
          cy="24"
          r={RADIUS}
          fill="none"
          stroke="var(--color-primary)"
          strokeWidth="2.5"
          strokeLinecap="round"
          strokeDasharray={CIRCUMFERENCE}
          strokeDashoffset={strokeDashoffset}
          className="transition-[stroke-dashoffset] duration-150 ease-out"
        />
      </svg>
      <ArrowUp className="size-5 transition-transform duration-200 ease-luna group-hover:-translate-y-0.5" />
    </button>
  )
}

