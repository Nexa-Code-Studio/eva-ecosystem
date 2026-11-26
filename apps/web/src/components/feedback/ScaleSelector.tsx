import { useState, type KeyboardEvent } from 'react'
import { cn } from '@/lib/cn'

export interface ScaleOptionMeta {
  title: string
  toneClass: string
}

interface ScaleSelectorProps {
  id: string
  questionLabel: string
  required?: boolean
  value: number
  onChange: (score: number) => void
  minLabel: string
  maxLabel: string
  scoreLabels: Record<number, ScaleOptionMeta>
  disabled?: boolean
}

export function ScaleSelector({
  id,
  questionLabel,
  required = true,
  value,
  onChange,
  minLabel,
  maxLabel,
  scoreLabels,
  disabled,
}: ScaleSelectorProps) {
  const [hovered, setHovered] = useState<number>(0)
  const previewScore = hovered || value
  const activeMeta = previewScore > 0 ? scoreLabels[previewScore] : null

  const handleKeyDown = (e: KeyboardEvent<HTMLButtonElement>, currentScore: number) => {
    if (disabled) return
    if (e.key === 'ArrowRight' || e.key === 'ArrowUp') {
      e.preventDefault()
      onChange(Math.min(5, (value || currentScore) + 1))
    } else if (e.key === 'ArrowLeft' || e.key === 'ArrowDown') {
      e.preventDefault()
      onChange(Math.max(1, (value || currentScore) - 1))
    }
  }

  return (
    <div className="rounded-[16px] border border-[#E2E8F0] bg-canvas/60 px-3.5 py-4 sm:px-4">
      <p id={`${id}-label`} className="text-sm font-bold text-ink">
        {questionLabel}
        {required && <span className="ml-1 text-[#B91C1C]">*</span>}
      </p>

      <div
        role="radiogroup"
        aria-labelledby={`${id}-label`}
        onMouseLeave={() => setHovered(0)}
        className="mt-3 grid grid-cols-5 gap-2 sm:gap-2.5"
      >
        {[1, 2, 3, 4, 5].map((score) => {
          const selected = value === score
          const labelMeta = scoreLabels[score]
          return (
            <button
              key={score}
              id={`${id}-option-${score}`}
              type="button"
              role="radio"
              aria-checked={selected}
              aria-label={`${score} dari 5 (${labelMeta?.title ?? score})`}
              disabled={disabled}
              onMouseEnter={() => !disabled && setHovered(score)}
              onClick={() => onChange(score)}
              onKeyDown={(e) => handleKeyDown(e, score)}
              className={cn(
                'flex min-h-11 cursor-pointer items-center justify-center rounded-[12px] border text-sm font-bold transition-colors focus-visible:outline-2 focus-visible:outline-primary disabled:cursor-not-allowed disabled:opacity-50 sm:min-h-12',
                selected
                  ? 'border-primary bg-primary text-white shadow-2xs'
                  : 'border-[#CBD5E1] bg-white text-ink hover:border-primary/50 hover:bg-[#EEF0FF]/40',
              )}
            >
              {score}
            </button>
          )
        })}
      </div>

      <div className="mt-2 flex items-center justify-between gap-2 text-[11px] font-medium text-ink-muted">
        <span>{minLabel}</span>
        <span className="text-right">{maxLabel}</span>
      </div>

      <div className="mt-2.5 flex min-h-7 items-center" aria-live="polite">
        {activeMeta ? (
          <span
            className={cn(
              'inline-flex items-center rounded-pill border px-2.5 py-0.5 text-xs font-bold',
              activeMeta.toneClass,
            )}
          >
            {previewScore}/5 · {activeMeta.title}
          </span>
        ) : (
          <span className="text-xs text-ink-muted">Pilih angka 1 sampai 5</span>
        )}
      </div>
    </div>
  )
}
