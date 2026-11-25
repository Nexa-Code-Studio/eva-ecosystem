import { useState } from 'react'
import { Star } from 'lucide-react'
import { cn } from '@/lib/cn'

const RATING_LABELS: Record<number, { title: string; toneClass: string }> = {
  1: { title: 'Kurang banget', toneClass: 'bg-[#FEF2F2] text-[#991B1B] border-[#FECACA]' },
  2: { title: 'Kurang pas', toneClass: 'bg-[#FFF7ED] text-[#9A3412] border-[#FED7AA]' },
  3: { title: 'Lumayan oke', toneClass: 'bg-[#FFFBEB] text-[#92400E] border-[#FDE68A]' },
  4: { title: 'Puas berkunjung', toneClass: 'bg-[#F0FDF4] text-[#166534] border-[#BBF7D0]' },
  5: { title: 'Keren banget!', toneClass: 'bg-[#FFFBEB] text-[#92400E] border-[#FDE68A]' },
}

interface RatingSelectorProps {
  value: number
  onChange: (rating: number) => void
  disabled?: boolean
}

export function RatingSelector({ value, onChange, disabled }: RatingSelectorProps) {
  const [hovered, setHovered] = useState<number>(0)
  const displayScore = hovered || value

  const handleKeyDown = (e: React.KeyboardEvent<HTMLButtonElement>, currentScore: number) => {
    if (disabled) return
    if (e.key === 'ArrowRight' || e.key === 'ArrowUp') {
      e.preventDefault()
      onChange(Math.min(5, (value || currentScore) + 1))
    } else if (e.key === 'ArrowLeft' || e.key === 'ArrowDown') {
      e.preventDefault()
      onChange(Math.max(1, (value || currentScore) - 1))
    }
  }

  const activeMeta = value > 0 ? RATING_LABELS[value] : null

  return (
    <div className="flex flex-col items-center">
      <div
        role="radiogroup"
        aria-label="Rating pengalaman mengunjungi booth EVA"
        onMouseLeave={() => setHovered(0)}
        className="flex items-center justify-center gap-2 sm:gap-3"
      >
        {[1, 2, 3, 4, 5].map((score) => {
          const selected = value === score
          const filled = displayScore >= score
          return (
            <button
              key={score}
              type="button"
              role="radio"
              aria-checked={selected}
              aria-label={`${score} dari 5 bintang (${RATING_LABELS[score].title})`}
              disabled={disabled}
              onMouseEnter={() => !disabled && setHovered(score)}
              onClick={() => onChange(score)}
              onKeyDown={(e) => handleKeyDown(e, score)}
              className={cn(
                'inline-flex size-12 cursor-pointer items-center justify-center rounded-full transition-transform duration-150 active:scale-90 focus-visible:outline-2 focus-visible:outline-primary disabled:cursor-not-allowed disabled:opacity-50 sm:size-13',
                filled ? 'bg-[#FFFBEB]/70' : 'hover:bg-canvas',
              )}
            >
              <Star
                className={cn(
                  'size-8 sm:size-9',
                  filled
                    ? 'fill-[#F59E0B] text-[#D97706]'
                    : 'fill-transparent text-[#94A3B8]',
                )}
                aria-hidden="true"
              />
            </button>
          )
        })}
      </div>

      <div className="mt-2.5 flex min-h-7 items-center justify-center" aria-live="polite">
        {activeMeta ? (
          <span
            className={cn(
              'inline-flex items-center rounded-pill border px-3 py-1 text-xs font-bold',
              activeMeta.toneClass,
            )}
          >
            {value}/5 · {activeMeta.title}
          </span>
        ) : (
          <span className="text-xs font-medium text-ink-muted">
            Ketuk bintang 1 sampai 5 sesuai pengalaman Anda
          </span>
        )}
      </div>
    </div>
  )
}
